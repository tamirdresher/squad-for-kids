<#
.SYNOPSIS
    Generates a personalized HTML birthday email for a DK8S Platform team member.

.DESCRIPTION
    Creates a warm, AI-crafted birthday email with:
    - Personalized contributions section (from WorkIQ research or fallback)
    - Styled HTML (Outlook-safe inline CSS, table layout)
    - CC list of all other team members
    Sends via Outlook COM automation.

.PARAMETER Name
    Full name of the birthday person.

.PARAMETER Role
    Their role/title on the team.

.PARAMETER Alias
    Microsoft alias (used for email: alias@microsoft.com).

.PARAMETER Contributions
    Optional array of contribution strings. If not provided, generic contributions are used.

.PARAMETER CcList
    Semicolon-separated CC addresses for other team members.

.PARAMETER OutputHtml
    If specified, saves HTML to this file path instead of sending email.

.PARAMETER Send
    If specified, sends the email via Outlook COM. Default is to only generate HTML.

.EXAMPLE
    .\birthday-email.ps1 -Name "Anand Kumar" -Role "Senior SDE" -Alias "anandkuma" -OutputHtml ".\birthday-preview.html"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [string]$Role,

    [Parameter(Mandatory = $true)]
    [string]$Alias,

    [Parameter(Mandatory = $false)]
    [string[]]$Contributions,

    [Parameter(Mandatory = $false)]
    [string]$CcList,

    [Parameter(Mandatory = $false)]
    [string]$OutputHtml,

    [Parameter(Mandatory = $false)]
    [switch]$Send
)

$ErrorActionPreference = "Stop"

# --- Inspiring quotes pool ---
$quotes = @(
    "The only way to do great work is to love what you do. — Steve Jobs",
    "Innovation distinguishes between a leader and a follower. — Steve Jobs",
    "Code is like humor. When you have to explain it, it's bad. — Cory House",
    "First, solve the problem. Then, write the code. — John Johnson",
    "The best time to plant a tree was 20 years ago. The second best time is now. — Chinese Proverb",
    "Alone we can do so little; together we can do so much. — Helen Keller",
    "Stay hungry, stay foolish. — Steve Jobs",
    "It always seems impossible until it is done. — Nelson Mandela",
    "The future belongs to those who believe in the beauty of their dreams. — Eleanor Roosevelt",
    "What we do in life echoes in eternity. — Marcus Aurelius"
)
$randomQuote = $quotes | Get-Random

# --- First name extraction ---
$firstName = ($Name -split " ")[0]

# --- Default contributions if none provided ---
if (-not $Contributions -or $Contributions.Count -eq 0) {
    $Contributions = @(
        "Being an invaluable member of the DK8S Platform team",
        "Bringing positive energy and collaboration to every standup",
        "Helping the team ship reliable infrastructure for our customers",
        "Contributing thoughtful code reviews that raise the quality bar",
        "Being a great teammate who's always ready to help"
    )
}

# --- Build contributions HTML ---
$contributionsHtml = ""
$emojis = @("🌟", "🚀", "💡", "🔧", "🏆", "⚡", "🎯", "💪")
$i = 0
foreach ($contribution in $Contributions) {
    $emoji = $emojis[$i % $emojis.Count]
    $contributionsHtml += @"
                            <tr>
                                <td style="padding: 8px 12px; font-size: 15px; color: #333333; border-bottom: 1px solid #f0f0f0;">
                                    $emoji $contribution
                                </td>
                            </tr>
"@
    $i++
}

# --- Build the HTML email ---
$htmlBody = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Happy Birthday $firstName!</title>
</head>
<body style="margin: 0; padding: 0; background-color: #f5f5f5; font-family: Segoe UI, Calibri, Arial, sans-serif;">
    <!-- Outer wrapper table -->
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background-color: #f5f5f5;">
        <tr>
            <td align="center" style="padding: 20px 10px;">
                <!-- Main card -->
                <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="600" style="max-width: 600px; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">

                    <!-- AI disclosure banner -->
                    <tr>
                        <td style="background-color: #2d2d2d; padding: 10px 24px; text-align: center;">
                            <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%">
                                <tr>
                                    <td style="font-size: 13px; color: #cccccc; text-align: center; font-family: Segoe UI, Calibri, Arial, sans-serif;">
                                        &#129302; This birthday greeting was lovingly crafted by Tamir's AI Squad &#127881;
                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>

                    <!-- Gradient header -->
                    <tr>
                        <td style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px 24px; text-align: center;">
                            <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%">
                                <tr>
                                    <td style="text-align: center;">
                                        <span style="font-size: 60px; line-height: 1;">&#127874;</span>
                                    </td>
                                </tr>
                                <tr>
                                    <td style="padding-top: 16px; text-align: center;">
                                        <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 700; font-family: Segoe UI, Calibri, Arial, sans-serif;">
                                            Happy Birthday, $firstName!
                                        </h1>
                                    </td>
                                </tr>
                                <tr>
                                    <td style="padding-top: 8px; text-align: center;">
                                        <p style="margin: 0; color: #e8e8ff; font-size: 16px; font-family: Segoe UI, Calibri, Arial, sans-serif;">
                                            $Role &bull; DK8S Platform Team
                                        </p>
                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>

                    <!-- Warm message -->
                    <tr>
                        <td style="padding: 28px 24px 16px 24px;">
                            <p style="margin: 0 0 16px 0; font-size: 16px; line-height: 1.6; color: #333333; font-family: Segoe UI, Calibri, Arial, sans-serif;">
                                Dear $firstName, &#127881;
                            </p>
                            <p style="margin: 0 0 16px 0; font-size: 16px; line-height: 1.6; color: #333333; font-family: Segoe UI, Calibri, Arial, sans-serif;">
                                On behalf of the entire <strong>DK8S Platform</strong> team, we want to wish you the happiest of birthdays! &#127873;
                                Today is all about celebrating <em>you</em> &#8212; your talent, your dedication, and the incredible energy you bring to our team every single day.
                            </p>
                        </td>
                    </tr>

                    <!-- Contributions section -->
                    <tr>
                        <td style="padding: 0 24px 20px 24px;">
                            <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background-color: #f8f9ff; border-radius: 8px; border: 1px solid #e8eaff;">
                                <tr>
                                    <td style="padding: 16px 16px 8px 16px;">
                                        <h2 style="margin: 0; font-size: 18px; color: #5b4ba2; font-family: Segoe UI, Calibri, Arial, sans-serif;">
                                            &#11088; Your Amazing Contributions This Year
                                        </h2>
                                    </td>
                                </tr>
                                <tr>
                                    <td style="padding: 4px 16px 16px 16px;">
                                        <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%">
$contributionsHtml
                                        </table>
                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>

                    <!-- Inspirational quote -->
                    <tr>
                        <td style="padding: 0 24px 24px 24px;">
                            <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background-color: #fff8e1; border-radius: 8px; border-left: 4px solid #ffc107;">
                                <tr>
                                    <td style="padding: 16px;">
                                        <p style="margin: 0; font-size: 15px; font-style: italic; color: #5d4e37; line-height: 1.5; font-family: Segoe UI, Calibri, Arial, sans-serif;">
                                            &#128161; &ldquo;$randomQuote&rdquo;
                                        </p>
                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>

                    <!-- Closing -->
                    <tr>
                        <td style="padding: 0 24px 24px 24px;">
                            <p style="margin: 0 0 8px 0; font-size: 16px; line-height: 1.6; color: #333333; font-family: Segoe UI, Calibri, Arial, sans-serif;">
                                Wishing you an incredible year ahead filled with joy, success, and amazing code! &#127752;
                            </p>
                            <p style="margin: 16px 0 0 0; font-size: 16px; color: #333333; font-family: Segoe UI, Calibri, Arial, sans-serif;">
                                <strong>With warm wishes from the entire DK8S Platform team</strong> &#127874;
                            </p>
                        </td>
                    </tr>

                    <!-- Footer -->
                    <tr>
                        <td style="background-color: #f0f0f5; padding: 16px 24px; text-align: center; border-top: 1px solid #e0e0e0;">
                            <p style="margin: 0; font-size: 12px; color: #888888; font-family: Segoe UI, Calibri, Arial, sans-serif;">
                                &#129302; Generated by Tamir's AI Squad &bull; Kes (Communications Agent)
                                <br>
                                This is an automated birthday greeting &#8212; no action required &#128522;
                            </p>
                        </td>
                    </tr>

                </table>
                <!-- End main card -->
            </td>
        </tr>
    </table>
</body>
</html>
"@

# --- Output or Send ---
if ($OutputHtml) {
    $htmlBody | Out-File -FilePath $OutputHtml -Encoding utf8
    Write-Host "Birthday email HTML saved to: $OutputHtml" -ForegroundColor Green
    return $htmlBody
}

if ($Send) {
    $subject = "🎂 Happy Birthday $Name! — From the DK8S Platform Team"
    $toAddress = "$Alias@microsoft.com"

    try {
        $outlook = New-Object -ComObject Outlook.Application
        $mail = $outlook.CreateItem(0)
        $mail.Subject = $subject
        $mail.HTMLBody = $htmlBody
        $mail.To = $toAddress

        if ($CcList) {
            $mail.CC = $CcList
        }

        $mail.Send()
        Write-Host "Birthday email sent to $toAddress!" -ForegroundColor Green

        if ($CcList) {
            Write-Host "CC: $CcList" -ForegroundColor Cyan
        }
    }
    catch {
        Write-Error "Failed to send email via Outlook COM: $_"
        # Fallback: save HTML
        $fallbackPath = Join-Path $PSScriptRoot "birthday-$Alias-fallback.html"
        $htmlBody | Out-File -FilePath $fallbackPath -Encoding utf8
        Write-Warning "Email saved to fallback file: $fallbackPath"
    }
}
else {
    # Just return the HTML
    return $htmlBody
}
