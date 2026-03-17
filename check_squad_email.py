#!/usr/bin/env python3
import imaplib
import email
from email.header import decode_header
import os
import sys
from datetime import datetime

# Get credentials from environment
email_addr = "td-squad-ai-team@outlook.com"
password = os.environ.get('SQUAD_EMAIL_PASSWORD')

if not password:
    print("❌ Password not found in environment")
    sys.exit(1)

print("📧 Connecting to Outlook IMAP...")
print(f"Email: {email_addr}")

try:
    # Connect to Outlook IMAP
    mail = imaplib.IMAP4_SSL('outlook.office365.com', 993)
    mail.login(email_addr, password)
    print("✅ Connected and authenticated!")
    
    # Select INBOX
    status, messages = mail.select('INBOX')
    print(f"📬 INBOX status: {status}")
    
    if status != 'OK':
        print("❌ Could not select INBOX")
        sys.exit(1)
    
    # Get the number of emails
    num_emails = messages[0].decode('utf-8')
    print(f"📨 Total emails in INBOX: {num_emails}")
    
    # Search for Gumroad emails
    print("\n🔍 Searching for Gumroad verification emails...")
    status, email_ids = mail.search(None, 'FROM', 'gumroad')
    
    if status != 'OK' or not email_ids[0]:
        print("❌ No Gumroad emails found with direct search, trying broader search...")
        status, email_ids = mail.search(None, 'ALL')
    
    email_id_list = email_ids[0].split()
    print(f"Found {len(email_id_list)} emails in INBOX")
    
    # Get the last 20 emails to check
    print("\n📬 Checking recent emails for Gumroad verification...")
    recent_ids = email_id_list[-20:]  # Last 20 emails
    
    gumroad_found = False
    
    for email_id in reversed(recent_ids):  # Check from newest to oldest
        status, msg_data = mail.fetch(email_id, '(RFC822)')
        
        if status != 'OK':
            continue
        
        msg = email.message_from_bytes(msg_data[0][1])
        
        # Get email details
        subject = decode_header(msg.get('Subject', ''))[0][0]
        if isinstance(subject, bytes):
            subject = subject.decode('utf-8', errors='ignore')
        
        from_addr = msg.get('From', '')
        date_str = msg.get('Date', '')
        
        # Check if this is a Gumroad email
        if 'gumroad' in from_addr.lower() or 'gumroad' in subject.lower() or 'verification' in subject.lower():
            print("\n" + "="*70)
            print(f"✅ FOUND EMAIL FROM: {from_addr}")
            print(f"   SUBJECT: {subject}")
            print(f"   DATE: {date_str}")
            
            # Get email body
            body = ""
            if msg.is_multipart():
                for part in msg.walk():
                    if part.get_content_type() == "text/plain":
                        try:
                            body = part.get_payload(decode=True).decode('utf-8', errors='ignore')
                        except:
                            body = part.get_payload()
                        break
            else:
                body = msg.get_payload(decode=True).decode('utf-8', errors='ignore') if msg.get_payload(decode=True) else msg.get_payload()
            
            # Look for verification link
            if 'http' in body:
                lines = body.split('\n')
                print("\n   📎 Links found in email:")
                for line in lines:
                    if 'http' in line and ('verify' in line.lower() or 'confirm' in line.lower() or 'gumroad' in line.lower()):
                        # Extract URL
                        import re
                        urls = re.findall(r'https?://[^\s\n\)>"\]]+', line)
                        for url in urls:
                            print(f"   🔗 {url}")
                            gumroad_found = True
            
            print("="*70)
    
    if not gumroad_found:
        print("\n⚠️  No Gumroad verification links found yet")
        print("\n📋 Most recent emails:")
        for email_id in reversed(recent_ids[-5:]):  # Show last 5
            status, msg_data = mail.fetch(email_id, '(RFC822)')
            msg = email.message_from_bytes(msg_data[0][1])
            subject = decode_header(msg.get('Subject', ''))[0][0]
            if isinstance(subject, bytes):
                subject = subject.decode('utf-8', errors='ignore')
            from_addr = msg.get('From', '')
            print(f"  - From: {from_addr} | Subject: {subject}")
    
    mail.close()
    mail.logout()
    
except imaplib.IMAP4.error as e:
    print(f"❌ IMAP error: {e}")
    sys.exit(1)
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

print("\n✅ Done!")
