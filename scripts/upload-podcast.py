#!/usr/bin/env python3
"""
Upload podcast audio files to OneDrive or Azure Blob Storage

This script uploads MP3/WAV podcast files to cloud storage and returns a shareable link.
Three methods are supported (in order of preference):
1. OneDrive Sync Folder - Simplest, works immediately if OneDrive is synced
2. Microsoft Graph API - Proper API integration (requires auth setup)
3. Azure Blob Storage - For Azure-native workflows (requires Azure CLI)

Usage:
    python upload-podcast.py <file-path> [--method <OneDriveSync|GraphAPI|AzureBlob>]
    
Examples:
    python upload-podcast.py RESEARCH_REPORT-audio.mp3
    python upload-podcast.py EXECUTIVE_SUMMARY-audio.mp3 --method GraphAPI
    python upload-podcast.py audio.mp3 --method AzureBlob --storage-account mystorage
"""

import argparse
import os
import sys
import time
import shutil
import subprocess
from pathlib import Path
from datetime import datetime, timedelta
import json

try:
    import requests
except ImportError:
    print("⚠️  'requests' library not found. Installing...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "requests"])
    import requests


class Colors:
    """ANSI color codes for terminal output"""
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    WHITE = '\033[97m'
    RESET = '\033[0m'


def print_colored(text, color):
    """Print colored text to terminal"""
    print(f"{color}{text}{Colors.RESET}")


def upload_to_onedrive_sync(file_path, relative_path='Squad/Podcasts'):
    """
    Upload file by copying to OneDrive sync folder
    Simplest method - works immediately if OneDrive is syncing
    """
    print_colored("📁 Using OneDrive Sync Folder method...", Colors.CYAN)
    
    # Find OneDrive folder
    onedrive_root = None
    possible_paths = [
        os.environ.get('OneDrive'),
        os.environ.get('OneDriveCommercial'),
        os.path.join(os.path.expanduser('~'), 'OneDrive'),
        os.path.join(os.path.expanduser('~'), 'OneDrive - Microsoft'),
    ]
    
    # Linux/Mac alternatives
    if sys.platform != 'win32':
        possible_paths.extend([
            os.path.join(os.path.expanduser('~'), 'OneDrive'),
            '/mnt/c/Users/' + os.environ.get('USER', '') + '/OneDrive',  # WSL
        ])
    
    for path in possible_paths:
        if path and os.path.isdir(path):
            onedrive_root = path
            break
    
    if not onedrive_root:
        raise Exception("OneDrive folder not found. Please ensure OneDrive is installed and syncing.")
    
    print_colored(f"✓ Found OneDrive folder: {onedrive_root}", Colors.GREEN)
    
    # Create destination folder
    dest_folder = os.path.join(onedrive_root, relative_path)
    os.makedirs(dest_folder, exist_ok=True)
    print_colored(f"✓ Created folder: {dest_folder}", Colors.GREEN)
    
    # Copy file
    dest_file = os.path.join(dest_folder, os.path.basename(file_path))
    shutil.copy2(file_path, dest_file)
    print_colored(f"✓ Copied to: {dest_file}", Colors.GREEN)
    
    # Wait for OneDrive to sync (basic heuristic)
    print_colored("⏳ Waiting for OneDrive sync (3 seconds)...", Colors.YELLOW)
    time.sleep(3)
    
    return {
        'success': True,
        'local_path': dest_file,
        'message': 'File copied to OneDrive sync folder. Share link: Right-click file in OneDrive → Share',
        'share_instructions': f"To get shareable link: Open OneDrive folder, right-click '{dest_file}', select 'Share', and copy the link."
    }


def upload_to_graph_api(file_path, relative_path='Squad/Podcasts'):
    """
    Upload file using Microsoft Graph API
    Requires Azure AD app registration and credentials
    """
    print_colored("🔐 Using Microsoft Graph API method...", Colors.CYAN)
    print()
    print_colored("⚠️  SETUP REQUIRED:", Colors.YELLOW)
    print_colored("   1. Register Azure AD app: https://portal.azure.com/#blade/Microsoft_AAD_RegisteredApps/ApplicationsListBlade", Colors.YELLOW)
    print_colored("   2. Add API permission: Files.ReadWrite (delegated or application)", Colors.YELLOW)
    print_colored("   3. Set environment variables:", Colors.YELLOW)
    print_colored("      - GRAPH_CLIENT_ID=<your-client-id>", Colors.YELLOW)
    print_colored("      - GRAPH_CLIENT_SECRET=<your-client-secret>", Colors.YELLOW)
    print_colored("      - GRAPH_TENANT_ID=<your-tenant-id>", Colors.YELLOW)
    print()
    
    client_id = os.environ.get('GRAPH_CLIENT_ID')
    client_secret = os.environ.get('GRAPH_CLIENT_SECRET')
    tenant_id = os.environ.get('GRAPH_TENANT_ID')
    
    if not (client_id and client_secret and tenant_id):
        raise Exception("Graph API credentials not configured. Please set GRAPH_CLIENT_ID, GRAPH_CLIENT_SECRET, and GRAPH_TENANT_ID environment variables.")
    
    # Get access token
    print_colored("🔑 Obtaining access token...", Colors.CYAN)
    token_url = f"https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token"
    token_data = {
        'client_id': client_id,
        'client_secret': client_secret,
        'scope': 'https://graph.microsoft.com/.default',
        'grant_type': 'client_credentials'
    }
    
    token_response = requests.post(token_url, data=token_data)
    token_response.raise_for_status()
    access_token = token_response.json()['access_token']
    
    # Upload file
    file_name = os.path.basename(file_path)
    upload_url = f"https://graph.microsoft.com/v1.0/me/drive/root:/{relative_path}/{file_name}:/content"
    
    print_colored(f"📤 Uploading {file_name}...", Colors.CYAN)
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/octet-stream'
    }
    
    with open(file_path, 'rb') as f:
        file_data = f.read()
    
    upload_response = requests.put(upload_url, headers=headers, data=file_data)
    upload_response.raise_for_status()
    upload_result = upload_response.json()
    
    # Create sharing link
    print_colored("🔗 Creating sharing link...", Colors.CYAN)
    item_id = upload_result['id']
    share_url = f"https://graph.microsoft.com/v1.0/me/drive/items/{item_id}/createLink"
    share_data = {
        'type': 'view',
        'scope': 'anonymous'
    }
    share_headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json'
    }
    
    share_response = requests.post(share_url, headers=share_headers, json=share_data)
    share_response.raise_for_status()
    share_result = share_response.json()
    
    return {
        'success': True,
        'share_link': share_result['link']['webUrl'],
        'download_url': upload_result.get('@microsoft.graph.downloadUrl'),
        'message': 'File uploaded successfully via Graph API'
    }


def upload_to_azure_blob(file_path, storage_account, container='podcasts'):
    """
    Upload file to Azure Blob Storage using Azure CLI
    Requires Azure CLI installed and logged in
    """
    print_colored("☁️  Using Azure Blob Storage method...", Colors.CYAN)
    
    if not storage_account:
        raise Exception("Storage account name is required for Azure Blob method. Use --storage-account parameter.")
    
    # Check if Azure CLI is installed
    try:
        subprocess.run(['az', '--version'], capture_output=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        raise Exception("Azure CLI (az) not found. Install from: https://aka.ms/installazurecliwindows")
    
    # Check if logged in
    print_colored("🔐 Checking Azure CLI login...", Colors.CYAN)
    try:
        account_info = subprocess.run(
            ['az', 'account', 'show'],
            capture_output=True,
            text=True,
            check=True
        )
        account_data = json.loads(account_info.stdout)
        print_colored(f"✓ Logged in as: {account_data['user']['name']}", Colors.GREEN)
    except subprocess.CalledProcessError:
        raise Exception("Not logged into Azure CLI. Run 'az login' first.")
    
    # Upload blob
    blob_name = os.path.basename(file_path)
    print_colored(f"📤 Uploading to {storage_account}/{container}/{blob_name}...", Colors.CYAN)
    
    upload_cmd = [
        'az', 'storage', 'blob', 'upload',
        '--account-name', storage_account,
        '--container-name', container,
        '--name', blob_name,
        '--file', file_path,
        '--overwrite',
        '--auth-mode', 'login'
    ]
    
    subprocess.run(upload_cmd, check=True, capture_output=True)
    
    # Generate SAS URL (valid for 90 days)
    print_colored("🔗 Generating SAS URL...", Colors.CYAN)
    expiry_date = (datetime.utcnow() + timedelta(days=90)).strftime('%Y-%m-%dT%H:%M:%SZ')
    
    sas_cmd = [
        'az', 'storage', 'blob', 'generate-sas',
        '--account-name', storage_account,
        '--container-name', container,
        '--name', blob_name,
        '--permissions', 'r',
        '--expiry', expiry_date,
        '--https-only',
        '--full-uri',
        '--auth-mode', 'login',
        '--output', 'tsv'
    ]
    
    sas_result = subprocess.run(sas_cmd, capture_output=True, text=True, check=True)
    sas_url = sas_result.stdout.strip()
    
    return {
        'success': True,
        'share_link': sas_url,
        'blob_url': f"https://{storage_account}.blob.core.windows.net/{container}/{blob_name}",
        'message': 'File uploaded to Azure Blob Storage (SAS valid for 90 days)'
    }


def main():
    parser = argparse.ArgumentParser(
        description='Upload podcast audio files to cloud storage',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python upload-podcast.py RESEARCH_REPORT-audio.mp3
  python upload-podcast.py audio.mp3 --method GraphAPI
  python upload-podcast.py audio.mp3 --method AzureBlob --storage-account mystorage
        """
    )
    
    parser.add_argument('file_path', help='Path to audio file (MP3 or WAV)')
    parser.add_argument('--method', choices=['OneDriveSync', 'GraphAPI', 'AzureBlob'],
                       default='OneDriveSync', help='Upload method (default: OneDriveSync)')
    parser.add_argument('--onedrive-path', default='Squad/Podcasts',
                       help='Relative path within OneDrive (default: Squad/Podcasts)')
    parser.add_argument('--storage-account', help='Azure Storage Account name (for AzureBlob)')
    parser.add_argument('--container', default='podcasts',
                       help='Azure Blob container name (default: podcasts)')
    
    args = parser.parse_args()
    
    try:
        # Validate file exists
        if not os.path.isfile(args.file_path):
            raise Exception(f"File not found: {args.file_path}")
        
        file_size_mb = os.path.getsize(args.file_path) / (1024 * 1024)
        
        print()
        print_colored("🎙️  Podcast Upload Tool", Colors.MAGENTA)
        print_colored("========================", Colors.MAGENTA)
        print_colored(f"File: {os.path.basename(args.file_path)} ({file_size_mb:.2f} MB)", Colors.WHITE)
        print_colored(f"Method: {args.method}", Colors.WHITE)
        print()
        
        # Execute upload
        if args.method == 'OneDriveSync':
            result = upload_to_onedrive_sync(args.file_path, args.onedrive_path)
        elif args.method == 'GraphAPI':
            result = upload_to_graph_api(args.file_path, args.onedrive_path)
        elif args.method == 'AzureBlob':
            result = upload_to_azure_blob(args.file_path, args.storage_account, args.container)
        
        # Output results
        print()
        print_colored("✅ SUCCESS", Colors.GREEN)
        print_colored("==========", Colors.GREEN)
        print_colored(result['message'], Colors.WHITE)
        
        if result.get('share_link'):
            print()
            print_colored("🔗 Share Link:", Colors.CYAN)
            print_colored(result['share_link'], Colors.YELLOW)
        
        if result.get('local_path'):
            print()
            print_colored("📁 Local Path:", Colors.CYAN)
            print_colored(result['local_path'], Colors.YELLOW)
        
        if result.get('share_instructions'):
            print()
            print_colored("ℹ️  Next Steps:", Colors.CYAN)
            print_colored(result['share_instructions'], Colors.WHITE)
        
        print()
        sys.exit(0)
        
    except Exception as e:
        print()
        print_colored("❌ ERROR", Colors.RED)
        print_colored("========", Colors.RED)
        print_colored(str(e), Colors.RED)
        print()
        
        # Provide helpful guidance
        if args.method == 'OneDriveSync':
            print_colored("💡 Troubleshooting:", Colors.YELLOW)
            print_colored("   - Ensure OneDrive is installed and syncing", Colors.YELLOW)
            print_colored("   - Check OneDrive folder: echo $OneDrive (Windows) or ~/OneDrive", Colors.YELLOW)
        elif args.method == 'GraphAPI':
            print_colored("💡 Try OneDrive Sync method instead:", Colors.YELLOW)
            print_colored(f"   python upload-podcast.py {args.file_path} --method OneDriveSync", Colors.YELLOW)
        elif args.method == 'AzureBlob':
            print_colored("💡 Try OneDrive Sync method instead:", Colors.YELLOW)
            print_colored(f"   python upload-podcast.py {args.file_path} --method OneDriveSync", Colors.YELLOW)
        
        print()
        sys.exit(1)


if __name__ == '__main__':
    main()
