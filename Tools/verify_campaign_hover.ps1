param(
    [string]$ProjectRoot = "D:\dOCS\test",
    [string]$MarkedImage = "F:\down\Marked_locations.png",
    [int]$AllowedAverageDistance = 8,
    [int]$AllowedMaxDistance = 24,
    [int]$SearchRadius = 180
)

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;

public class CampaignHoverVerifier {
    class Room {
        public string Name;
        public List<Point> Points = new List<Point>();
    }

    static bool IsRed(Color c) {
        return c.R > 160 && c.G < 95 && c.B < 95 && c.R > c.G * 1.8 && c.R > c.B * 1.8;
    }

    static List<Room> ParseRooms(string gdText) {
        var rooms = new List<Room>();
        var roomMatches = Regex.Matches(gdText, "\\\"section\\\"\\s*:\\s*\\\"([^\\\"]+)\\\",\\s*\\\"points\\\"\\s*:\\s*\\[([\\s\\S]*?)\\]");
        foreach (Match roomMatch in roomMatches) {
            Room room = new Room();
            room.Name = roomMatch.Groups[1].Value;
            string body = roomMatch.Groups[2].Value;
            var pointMatches = Regex.Matches(body, "_campaign_map_point\\(([-0-9.]+),\\s*([-0-9.]+)\\)");
            foreach (Match pointMatch in pointMatches) {
                double x = Double.Parse(pointMatch.Groups[1].Value, System.Globalization.CultureInfo.InvariantCulture);
                double y = Double.Parse(pointMatch.Groups[2].Value, System.Globalization.CultureInfo.InvariantCulture);
                room.Points.Add(new Point((int)Math.Round(x), (int)Math.Round(y)));
            }
            if (room.Points.Count > 2) rooms.Add(room);
        }
        return rooms;
    }

    static double DistanceToNearestRed(bool[] red, int w, int h, int x, int y, int maxRadius) {
        if (x >= 0 && y >= 0 && x < w && y < h && red[y * w + x]) return 0.0;
        for (int r = 1; r <= maxRadius; r++) {
            double best = Double.PositiveInfinity;
            int left = x - r;
            int right = x + r;
            int top = y - r;
            int bottom = y + r;
            for (int px = left; px <= right; px++) {
                if (px >= 0 && px < w) {
                    if (top >= 0 && top < h && red[top * w + px]) {
                        double dx = px - x; double dy = top - y; double d = dx * dx + dy * dy;
                        if (d < best) best = d;
                    }
                    if (bottom >= 0 && bottom < h && red[bottom * w + px]) {
                        double dx = px - x; double dy = bottom - y; double d = dx * dx + dy * dy;
                        if (d < best) best = d;
                    }
                }
            }
            for (int py = top + 1; py <= bottom - 1; py++) {
                if (py >= 0 && py < h) {
                    if (left >= 0 && left < w && red[py * w + left]) {
                        double dx = left - x; double dy = py - y; double d = dx * dx + dy * dy;
                        if (d < best) best = d;
                    }
                    if (right >= 0 && right < w && red[py * w + right]) {
                        double dx = right - x; double dy = py - y; double d = dx * dx + dy * dy;
                        if (d < best) best = d;
                    }
                }
            }
            if (!Double.IsPositiveInfinity(best)) return Math.Sqrt(best);
        }
        return maxRadius + 1.0;
    }

    static bool SegmentShouldBeChecked(bool[] red, int w, int h, Point a, Point b, int allowedDistance) {
        int samples = Math.Max(4, (int)(Math.Sqrt((a.X - b.X) * (a.X - b.X) + (a.Y - b.Y) * (a.Y - b.Y)) / 12));
        int near = 0;
        for (int i = 0; i <= samples; i++) {
            double t = samples == 0 ? 0.0 : (double)i / samples;
            int x = (int)Math.Round(a.X + (b.X - a.X) * t);
            int y = (int)Math.Round(a.Y + (b.Y - a.Y) * t);
            if (DistanceToNearestRed(red, w, h, x, y, allowedDistance) <= allowedDistance) near++;
        }
        return near >= Math.Max(2, samples / 2);
    }
    public static int Run(string projectRoot, string markedImage, int allowedAverageDistance, int allowedMaxDistance, int searchRadius) {
        string campaignScript = Path.Combine(projectRoot, "Campaign", "campaign_screen.gd");
        string outDir = Path.Combine(projectRoot, "Tools", "hover_verify_output");
        Directory.CreateDirectory(outDir);
        string outImage = Path.Combine(outDir, "campaign_hover_compare.png");
        string outText = Path.Combine(outDir, "campaign_hover_report.txt");
        if (!File.Exists(campaignScript)) throw new Exception("campaign_screen.gd not found: " + campaignScript);
        if (!File.Exists(markedImage)) throw new Exception("marked image not found: " + markedImage);

        string gdText = File.ReadAllText(campaignScript, Encoding.UTF8);
        List<Room> rooms = ParseRooms(gdText);
        if (rooms.Count == 0) throw new Exception("No campaign room polygons found. Expected _campaign_map_point(x, y) points.");

        using (Bitmap src = new Bitmap(markedImage)) {
            int w = src.Width;
            int h = src.Height;
            bool[] red = new bool[w * h];
            int redCount = 0;
            for (int y = 0; y < h; y++) {
                for (int x = 0; x < w; x++) {
                    if (IsRed(src.GetPixel(x, y))) {
                        red[y * w + x] = true;
                        redCount++;
                    }
                }
            }
            if (redCount == 0) throw new Exception("No red contour pixels detected in marked image.");

            using (Bitmap edge = new Bitmap(w, h, PixelFormat.Format32bppArgb)) {
                using (Graphics ge = Graphics.FromImage(edge)) {
                    ge.Clear(Color.Transparent);
                    using (Pen pen = new Pen(Color.White, 3)) {
                        foreach (Room room in rooms) {
                            Point[] arr = room.Points.ToArray();
                            for (int i = 0; i < arr.Length - 1; i++) ge.DrawLine(pen, arr[i], arr[i + 1]);
                            if (arr.Length > 2 && SegmentShouldBeChecked(red, w, h, arr[arr.Length - 1], arr[0], allowedMaxDistance)) {
                                ge.DrawLine(pen, arr[arr.Length - 1], arr[0]);
                            }
                        }
                    }
                }

                var edgePoints = new List<Point>();
                for (int y = 0; y < h; y++) {
                    for (int x = 0; x < w; x++) {
                        if (edge.GetPixel(x, y).A > 0 && y < h - 4) edgePoints.Add(new Point(x, y));
                    }
                }

                double sum = 0.0;
                double max = 0.0;
                int bad = 0;
                foreach (Point p in edgePoints) {
                    double dist = DistanceToNearestRed(red, w, h, p.X, p.Y, searchRadius);
                    sum += dist;
                    if (dist > max) max = dist;
                    if (dist > allowedMaxDistance) bad++;
                }
                double avg = edgePoints.Count > 0 ? sum / edgePoints.Count : 999999.0;
                bool passed = avg <= allowedAverageDistance && max <= allowedMaxDistance && bad == 0;

                var report = new List<string>();
                report.Add("Campaign hover contour verification");
                report.Add("Marked image: " + markedImage);
                report.Add("Campaign script: " + campaignScript);
                report.Add("Image size: " + w + "x" + h);
                report.Add("Rooms: " + rooms.Count);
                foreach (Room room in rooms) report.Add("- " + room.Name + ": " + room.Points.Count + " points");
                report.Add("Red pixels detected: " + redCount);
                report.Add("Edge pixels checked: " + edgePoints.Count);
                report.Add(String.Format(System.Globalization.CultureInfo.InvariantCulture, "Average edge distance to red: {0:0.00}px", avg));
                report.Add(String.Format(System.Globalization.CultureInfo.InvariantCulture, "Max edge distance to red: {0:0.00}px", max));
                report.Add("Edge pixels farther than " + allowedMaxDistance + "px: " + bad);
                report.Add("PASS: " + passed);

                using (Bitmap overlay = new Bitmap(w, h, PixelFormat.Format32bppArgb)) {
                    using (Graphics g = Graphics.FromImage(overlay)) {
                        g.DrawImage(src, 0, 0, w, h);
                        using (SolidBrush fill = new SolidBrush(Color.FromArgb(60, 255, 255, 255)))
                        using (Pen white = new Pen(Color.FromArgb(230, 255, 255, 255), 2))
                        using (SolidBrush miss = new SolidBrush(Color.FromArgb(230, 0, 255, 255)))
                        using (Font font = new Font("Arial", 18, FontStyle.Bold))
                        using (SolidBrush textBrush = new SolidBrush(Color.White))
                        using (SolidBrush shadowBrush = new SolidBrush(Color.Black)) {
                            foreach (Room room in rooms) {
                                Point[] arr = room.Points.ToArray();
                                g.FillPolygon(fill, arr);
                                for (int i = 0; i < arr.Length - 1; i++) g.DrawLine(white, arr[i], arr[i + 1]);
                                if (arr.Length > 2 && SegmentShouldBeChecked(red, w, h, arr[arr.Length - 1], arr[0], allowedMaxDistance)) {
                                    g.DrawLine(white, arr[arr.Length - 1], arr[0]);
                                }
                            }
                            foreach (Point p in edgePoints) {
                                double dist = DistanceToNearestRed(red, w, h, p.X, p.Y, searchRadius);
                                if (dist > allowedMaxDistance) g.FillEllipse(miss, p.X - 2, p.Y - 2, 4, 4);
                            }
                            string summary = String.Format(System.Globalization.CultureInfo.InvariantCulture, "avg={0:0.0}px max={1:0.0}px bad>{2}px={3} pass={4}", avg, max, allowedMaxDistance, bad, passed);
                            g.DrawString(summary, font, shadowBrush, 13, 13);
                            g.DrawString(summary, font, textBrush, 10, 10);
                        }
                    }
                    overlay.Save(outImage, ImageFormat.Png);
                }
                File.WriteAllLines(outText, report.ToArray(), new UTF8Encoding(false));
                foreach (string line in report) Console.WriteLine(line);
                Console.WriteLine("Overlay: " + outImage);
                Console.WriteLine("Report: " + outText);
                return passed ? 0 : 2;
            }
        }
    }
}
"@

exit ([CampaignHoverVerifier]::Run($ProjectRoot, $MarkedImage, $AllowedAverageDistance, $AllowedMaxDistance, $SearchRadius))