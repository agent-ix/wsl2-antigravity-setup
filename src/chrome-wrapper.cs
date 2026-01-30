using System;
using System.Diagnostics;
using System.Linq;

class ChromeWrapper {
    static void Main(string[] args) {
        var psi = new ProcessStartInfo();
        // Chrome path is substituted at build time
        psi.FileName = @"{{CHROME_PATH}}";
        psi.Arguments =
            "--remote-debugging-port=9222 " +
            "--remote-debugging-address=127.0.0.1 " +
            string.Join(" ", args.Select(a => "\"" + a + "\""));
        psi.UseShellExecute = false;
        Process.Start(psi);
    }
}