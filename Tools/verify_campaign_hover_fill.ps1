param(
    [string]$ProjectRoot = "D:\dOCS\test",
    [string]$MarkedImage = "F:\down\Marked_locations.png"
)

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;

public class CampaignHoverMaskVerifier {
    class Room {
        public string Id;
        public string Name;
        public string Mask;
        public int X0,Y0,X1,Y1,SeedX,SeedY;
    }

    static bool IsRed(Color c) {
        return c.R > 160 && c.G < 95 && c.B < 95 && c.R > c.G * 1.8 && c.R > c.B * 1.8;
    }

    static int ScaleCoord(int value, int srcMax, int dstMax) {
        if (srcMax <= 0 || dstMax <= 0) return value;
        return (int)Math.Round(value * (double)dstMax / (double)srcMax);
    }

    static bool MarkedIsRedScaled(Bitmap marked, int x, int y, int w, int h) {
        int mx = ScaleCoord(x, w - 1, marked.Width - 1);
        int my = ScaleCoord(y, h - 1, marked.Height - 1);
        mx = Math.Max(0, Math.Min(marked.Width - 1, mx));
        my = Math.Max(0, Math.Min(marked.Height - 1, my));
        return IsRed(marked.GetPixel(mx, my));
    }

    static bool[] ExpectedMask(Bitmap marked, Room room, int w, int h) {
        bool[] barrier = new bool[w * h];
        bool[] fill = new bool[w * h];
        int x0 = ScaleCoord(room.X0, marked.Width - 1, w - 1);
        int x1 = ScaleCoord(room.X1, marked.Width - 1, w - 1);
        int y0 = ScaleCoord(room.Y0, marked.Height - 1, h - 1);
        int y1 = ScaleCoord(room.Y1, marked.Height - 1, h - 1);
        int sx = ScaleCoord(room.SeedX, marked.Width - 1, w - 1);
        int sy = ScaleCoord(room.SeedY, marked.Height - 1, h - 1);
        x0 = Math.Max(0, Math.Min(w - 1, x0)); x1 = Math.Max(0, Math.Min(w - 1, x1));
        y0 = Math.Max(0, Math.Min(h - 1, y0)); y1 = Math.Max(0, Math.Min(h - 1, y1));
        sx = Math.Max(0, Math.Min(w - 1, sx)); sy = Math.Max(0, Math.Min(h - 1, sy));
        int rad = 5;
        for (int y = y0; y <= y1; y++) {
            for (int x = x0; x <= x1; x++) {
                if (!MarkedIsRedScaled(marked, x, y, w, h)) continue;
                for (int yy = y - rad; yy <= y + rad; yy++) {
                    if (yy < 0 || yy >= h) continue;
                    for (int xx = x - rad; xx <= x + rad; xx++) {
                        if (xx < 0 || xx >= w) continue;
                        barrier[yy * w + xx] = true;
                    }
                }
            }
        }
        Queue<Point> q = new Queue<Point>();
        int seedIdx = sy * w + sx;
        if (!barrier[seedIdx]) {
            fill[seedIdx] = true;
            q.Enqueue(new Point(sx, sy));
        }
        int[] dx = {1, -1, 0, 0};
        int[] dy = {0, 0, 1, -1};
        while (q.Count > 0) {
            Point p = q.Dequeue();
            for (int i = 0; i < 4; i++) {
                int nx = p.X + dx[i];
                int ny = p.Y + dy[i];
                if (nx < x0 || nx > x1 || ny < y0 || ny > y1 || nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
                int idx = ny * w + nx;
                if (fill[idx] || barrier[idx]) continue;
                fill[idx] = true;
                q.Enqueue(new Point(nx, ny));
            }
        }
        return fill;
    }

    static bool[] ActualMask(Bitmap mask) {
        int w = mask.Width, h = mask.Height;
        bool[] actual = new bool[w * h];
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                if (mask.GetPixel(x, y).A > 0) actual[y * w + x] = true;
            }
        }
        return actual;
    }

    static Room[] Rooms() {
        return new Room[] {
            new Room{Id="library", Name="library", Mask="Campaign_Hover_library.png", X0=0,Y0=25,X1=265,Y1=850,SeedX=120,SeedY=420},
            new Room{Id="memory_well", Name="memory_well", Mask="Campaign_Hover_memory_well.png", X0=260,Y0=80,X1=505,Y1=825,SeedX=380,SeedY=430},
            new Room{Id="altar", Name="altar", Mask="Campaign_Hover_altar.png", X0=500,Y0=105,X1=720,Y1=810,SeedX=600,SeedY=430},
            new Room{Id="gates", Name="gates", Mask="Campaign_Hover_gates.png", X0=635,Y0=25,X1=1055,Y1=935,SeedX=840,SeedY=430},
            new Room{Id="creation_garden", Name="creation_garden", Mask="Campaign_Hover_creation_garden.png", X0=975,Y0=100,X1=1205,Y1=810,SeedX=1085,SeedY=430},
            new Room{Id="decoration_halls", Name="decoration_halls", Mask="Campaign_Hover_decoration_halls.png", X0=1185,Y0=90,X1=1438,Y1=830,SeedX=1310,SeedY=430},
            new Room{Id="scales", Name="scales", Mask="Campaign_Hover_scales.png", X0=1420,Y0=60,X1=1680,Y1=855,SeedX=1550,SeedY=430}
        };
    }

    public static int Run(string projectRoot, string markedImage) {
        string bgPath = Path.Combine(projectRoot, "Background", "Campaign_Background.png");
        string outDir = Path.Combine(projectRoot, "Tools", "hover_verify_output");
        Directory.CreateDirectory(outDir);
        List<string> report = new List<string>();
        bool all = true;
        using (Bitmap marked = new Bitmap(markedImage))
        using (Bitmap bg = new Bitmap(bgPath))
        using (Bitmap overlay = new Bitmap(bg.Width, bg.Height, PixelFormat.Format32bppArgb)) {
            using (Graphics g = Graphics.FromImage(overlay)) {
                g.DrawImage(bg, 0, 0, bg.Width, bg.Height);
                foreach (Room room in Rooms()) {
                    string maskPath = Path.Combine(projectRoot, "Background", room.Mask);
                    if (!File.Exists(maskPath)) {
                        all = false;
                        report.Add(room.Id + ": missing mask " + maskPath);
                        continue;
                    }
                    using (Bitmap mask = new Bitmap(maskPath)) {
                        if (mask.Width != bg.Width || mask.Height != bg.Height) {
                            all = false;
                            report.Add(String.Format("{0}: wrong size {1}x{2}, expected {3}x{4}", room.Id, mask.Width, mask.Height, bg.Width, bg.Height));
                            continue;
                        }
                        bool[] expected = ExpectedMask(marked, room, mask.Width, mask.Height);
                        bool[] actual = ActualMask(mask);
                        int e = 0, a = 0, inter = 0, fp = 0, fn = 0;
                        for (int y = 0; y < mask.Height; y++) {
                            for (int x = 0; x < mask.Width; x++) {
                                int idx = y * mask.Width + x;
                                bool ex = expected[idx];
                                bool ac = actual[idx];
                                if (ex) e++;
                                if (ac) a++;
                                if (ex && ac) inter++;
                                if (ac && !ex) fp++;
                                if (ex && !ac) fn++;
                            }
                        }
                        double iou = (e + a - inter) > 0 ? (double)inter / (double)(e + a - inter) : 0.0;
                        bool pass = iou >= 0.985 && fp <= Math.Max(300, e / 200) && fn <= Math.Max(300, e / 200);
                        if (!pass) all = false;
                        report.Add(String.Format(System.Globalization.CultureInfo.InvariantCulture, "{0}: expected={1} actual={2} intersection={3} IoU={4:0.0000} FP={5} FN={6} PASS={7}", room.Id, e, a, inter, iou, fp, fn, pass));
                        using (SolidBrush matched = new SolidBrush(Color.FromArgb(45, 255, 255, 255)))
                        using (SolidBrush outside = new SolidBrush(Color.FromArgb(150, 255, 130, 0)))
                        using (SolidBrush missing = new SolidBrush(Color.FromArgb(150, 0, 170, 255))) {
                            for (int y = 0; y < mask.Height; y += 2) {
                                for (int x = 0; x < mask.Width; x += 2) {
                                    int idx = y * mask.Width + x;
                                    bool ex = expected[idx];
                                    bool ac = actual[idx];
                                    if (ex && ac) g.FillRectangle(matched, x, y, 2, 2);
                                    else if (ac && !ex) g.FillRectangle(outside, x, y, 2, 2);
                                    else if (ex && !ac) g.FillRectangle(missing, x, y, 2, 2);
                                }
                            }
                        }
                    }
                }
            }
            string overlayPath = Path.Combine(outDir, "campaign_hover_mask_compare.png");
            overlay.Save(overlayPath, ImageFormat.Png);
            report.Insert(0, "MASK PASS: " + all);
            report.Add("Overlay: " + overlayPath);
            string reportPath = Path.Combine(outDir, "campaign_hover_mask_report.txt");
            File.WriteAllLines(reportPath, report.ToArray(), new UTF8Encoding(false));
            foreach (string line in report) Console.WriteLine(line);
        }
        return all ? 0 : 2;
    }
}
"@
exit ([CampaignHoverMaskVerifier]::Run($ProjectRoot, $MarkedImage))