namespace UbosProvisioner.Models;

public class AdbResult
{
    public int ExitCode { get; set; }
    public string Output { get; set; } = string.Empty;
    public string Error { get; set; } = string.Empty;
    public bool IsSuccess => ExitCode == 0;
}
