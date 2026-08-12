using System;
using System.IO;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;

class Room { public string Mask; public int X0,Y0,X1,Y1,SeedX,SeedY; }
class Program {
    static bool IsRed(Color c) { return c.R > 160 && c.G < 95 && c.B < 95 && c.R > c.G * 1.8 && c.R > c.B * 1.8; }
    static int ScaleCoord(int value, int srcMax, int dstMax) { return srcMax <= 0 || dstMax <= 0 ? value : (int)Math.Round(value * (double)dstMax / (double)srcMax); }
    static bool MarkedIsRedScaled(Bitmap marked, int x, int y, int w, int h) {
        int mx = Math.Max(0, Math.Min(marked.Width - 1, ScaleCoord(x, w - 1, marked.Width - 1)));
        int my = Math.Max(0, Math.Min(marked.Height - 1, ScaleCoord(y, h - 1, marked.Height - 1)));
        return IsRed(marked.GetPixel(mx, my));
    }
    static bool[] ExpectedMask(Bitmap marked, Room room, int w, int h) {
        bool[] barrier = new bool[w * h]; bool[] fill = new bool[w * h];
        int x0 = Math.Max(0, Math.Min(w - 1, ScaleCoord(room.X0, marked.Width - 1, w - 1)));
        int x1 = Math.Max(0, Math.Min(w - 1, ScaleCoord(room.X1, marked.Width - 1, w - 1)));
        int y0 = Math.Max(0, Math.Min(h - 1, ScaleCoord(room.Y0, marked.Height - 1, h - 1)));
        int y1 = Math.Max(0, Math.Min(h - 1, ScaleCoord(room.Y1, marked.Height - 1, h - 1)));
        int sx = Math.Max(0, Math.Min(w - 1, ScaleCoord(room.SeedX, marked.Width - 1, w - 1)));
        int sy = Math.Max(0, Math.Min(h - 1, ScaleCoord(room.SeedY, marked.Height - 1, h - 1)));
        int rad = 5;
        for (int y = y0; y <= y1; y++) for (int x = x0; x <= x1; x++) if (MarkedIsRedScaled(marked, x, y, w, h)) {
            for (int yy = y - rad; yy <= y + rad; yy++) if (yy >= 0 && yy < h)
                for (int xx = x - rad; xx <= x + rad; xx++) if (xx >= 0 && xx < w) barrier[yy * w + xx] = true;
        }
        Queue<Point> q = new Queue<Point>(); int seedIdx = sy * w + sx;
        if (!barrier[seedIdx]) { fill[seedIdx] = true; q.Enqueue(new Point(sx, sy)); }
        int[] dx = {1,-1,0,0}; int[] dy = {0,0,1,-1};
        while (q.Count > 0) { Point p = q.Dequeue(); for (int i = 0; i < 4; i++) {
            int nx = p.X + dx[i], ny = p.Y + dy[i];
            if (nx < x0 || nx > x1 || ny < y0 || ny > y1 || nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
            int idx = ny * w + nx; if (fill[idx] || barrier[idx]) continue; fill[idx] = true; q.Enqueue(new Point(nx, ny));
        }}
        return fill;
    }
    static Room[] Rooms() { return new Room[] {
        new Room{Mask="Campaign_Hover_library.png", X0=0,Y0=25,X1=265,Y1=850,SeedX=120,SeedY=420},
        new Room{Mask="Campaign_Hover_memory_well.png", X0=260,Y0=80,X1=505,Y1=825,SeedX=380,SeedY=430},
        new Room{Mask="Campaign_Hover_altar.png", X0=500,Y0=105,X1=720,Y1=810,SeedX=600,SeedY=430},
        new Room{Mask="Campaign_Hover_gates.png", X0=635,Y0=25,X1=1055,Y1=935,SeedX=840,SeedY=430},
        new Room{Mask="Campaign_Hover_creation_garden.png", X0=975,Y0=100,X1=1205,Y1=810,SeedX=1085,SeedY=430},
        new Room{Mask="Campaign_Hover_decoration_halls.png", X0=1185,Y0=90,X1=1438,Y1=830,SeedX=1310,SeedY=430},
        new Room{Mask="Campaign_Hover_scales.png", X0=1420,Y0=60,X1=1680,Y1=855,SeedX=1550,SeedY=430}
    };}
    static void Main(string[] args) {
        string projectRoot = @"D:\dOCS\test"; string markedPath = @"F:\down\Marked_locations.png";
        string bgPath = Path.Combine(projectRoot, "Background", "Campaign_Background.png");
        using (Bitmap marked = new Bitmap(markedPath)) using (Bitmap bg = new Bitmap(bgPath)) {
            foreach (Room room in Rooms()) {
                bool[] fill = ExpectedMask(marked, room, bg.Width, bg.Height);
                using (Bitmap outMask = new Bitmap(bg.Width, bg.Height, PixelFormat.Format32bppArgb)) {
                    for (int y = 0; y < bg.Height; y++) for (int x = 0; x < bg.Width; x++) if (fill[y * bg.Width + x]) outMask.SetPixel(x, y, Color.FromArgb(38, 255, 255, 255));
                    string outPath = Path.Combine(projectRoot, "Background", room.Mask);
                    outMask.Save(outPath, ImageFormat.Png);
                    Console.WriteLine(outPath);
                }
            }
        }
    }
}