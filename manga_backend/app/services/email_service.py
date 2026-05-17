import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from app.core.config import settings

class EmailService:
    def send_otp(self, to_email: str, otp: str, is_register: bool = False):
        subject = "Xác nhận đăng ký tài khoản MangaLibrary" if is_register else "Khôi phục mật khẩu MangaLibrary"
        action = "đăng ký tài khoản" if is_register else "khôi phục mật khẩu"
        
        body = f"""
        <html>
            <body style="font-family: Arial, sans-serif; padding: 20px; color: #333;">
                <h2>MangaLibrary</h2>
                <p>Xin chào,</p>
                <p>Mã xác nhận để {action} của bạn là: <strong style="font-size: 24px; color: #1ED760; letter-spacing: 2px;">{otp}</strong></p>
                <p>Mã này có hiệu lực trong vòng 5 phút. Vui lòng không chia sẻ mã này cho bất kỳ ai.</p>
                <p>Trân trọng,<br>Đội ngũ MangaLibrary</p>
            </body>
        </html>
        """
        
        msg = MIMEMultipart()
        msg['From'] = settings.SMTP_ACCOUNT
        msg['To'] = to_email
        msg['Subject'] = subject
        msg.attach(MIMEText(body, 'html'))

        try:
            server = smtplib.SMTP(settings.SMTP_SERVER, settings.SMTP_PORT)
            server.starttls()
            server.login(settings.SMTP_ACCOUNT, settings.SMTP_PASSWORD)
            server.send_message(msg)
            server.quit()
            print(f"[EmailService] Đã gửi mã OTP đến {to_email}")
        except Exception as e:
            print(f"[EmailService] Lỗi khi gửi mail đến {to_email}: {e}")

email_service = EmailService()