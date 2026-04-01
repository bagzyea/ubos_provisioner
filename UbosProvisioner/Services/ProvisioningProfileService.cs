using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;
using UbosProvisioner.Models;

namespace UbosProvisioner.Services;

public class ProvisioningProfileService
{
    private readonly string _profilesDirectory;

    public ProvisioningProfileService()
    {
        _profilesDirectory = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Profiles");
        Directory.CreateDirectory(_profilesDirectory);
    }

    /// <summary>
    /// Save provisioning configuration as a named profile.
    /// </summary>
    public async Task<string> SaveProfileAsync(string profileName, ProvisioningConfig config)
    {
        try
        {
            string filename = $"{profileName}.json";
            string filepath = Path.Combine(_profilesDirectory, filename);

            var json = JsonSerializer.Serialize(config, new JsonSerializerOptions { WriteIndented = true });
            await File.WriteAllTextAsync(filepath, json);

            return filepath;
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException($"Failed to save profile: {ex.Message}", ex);
        }
    }

    /// <summary>
    /// Load provisioning configuration from a named profile.
    /// </summary>
    public async Task<ProvisioningConfig> LoadProfileAsync(string profileName)
    {
        try
        {
            string filename = $"{profileName}.json";
            string filepath = Path.Combine(_profilesDirectory, filename);

            if (!File.Exists(filepath))
                throw new FileNotFoundException($"Profile not found: {profileName}");

            var json = await File.ReadAllTextAsync(filepath);
            var config = JsonSerializer.Deserialize<ProvisioningConfig>(json);

            return config ?? new ProvisioningConfig();
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException($"Failed to load profile: {ex.Message}", ex);
        }
    }

    /// <summary>
    /// List all available profiles.
    /// </summary>
    public List<string> GetAvailableProfiles()
    {
        var profiles = new List<string>();

        try
        {
            var files = Directory.GetFiles(_profilesDirectory, "*.json");
            foreach (var file in files)
            {
                profiles.Add(Path.GetFileNameWithoutExtension(file));
            }
        }
        catch
        {
            // Return empty list if directory operations fail
        }

        return profiles;
    }

    /// <summary>
    /// Delete a profile.
    /// </summary>
    public async Task DeleteProfileAsync(string profileName)
    {
        try
        {
            string filename = $"{profileName}.json";
            string filepath = Path.Combine(_profilesDirectory, filename);

            if (File.Exists(filepath))
                File.Delete(filepath);
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException($"Failed to delete profile: {ex.Message}", ex);
        }
    }
}
