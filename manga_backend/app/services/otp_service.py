import random
import time

class OTPService:
    def __init__(self):
        self._memory_otps: dict[str, dict] = {}

    def _generate_otp(self) -> str:
        return str(random.randint(100000, 999999))

    def set_otp(self, email: str, ttl: int = 300) -> str:
        otp = self._generate_otp()
        self._memory_otps[email] = {
            "otp": otp,
            "expires_at": time.time() + ttl
        }
        return otp

    def verify_otp(self, email: str, otp: str) -> bool:
        record = self._memory_otps.get(email)
        if not record:
            return False
        
        if time.time() > record["expires_at"]:
            self._memory_otps.pop(email, None)
            return False
            
        if record["otp"] != otp:
            return False
            
        return True

    def delete_otp(self, email: str):
        self._memory_otps.pop(email, None)

otp_service = OTPService()