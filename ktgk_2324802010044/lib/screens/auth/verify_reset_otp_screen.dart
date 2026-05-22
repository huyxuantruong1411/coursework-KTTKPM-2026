// lib/screens/auth/verify_reset_otp_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'reset_password_screen.dart';

const _kOrange = Color(0xFFFF6740);

class VerifyResetOtpScreen extends StatefulWidget {
  final String email;
  const VerifyResetOtpScreen({super.key, required this.email});

  @override
  State<VerifyResetOtpScreen> createState() => _VerifyResetOtpScreenState();
}

class _VerifyResetOtpScreenState extends State<VerifyResetOtpScreen> {
  final _otpCtrl = TextEditingController();

  // ── Countdown timer ──────────────────────────────────────────────────
  static const _otpTtlSeconds = 300; // 5 phút
  Timer? _timer;
  int _secondsLeft = _otpTtlSeconds;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _otpTtlSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String get _timerLabel {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  bool get _isExpired => _secondsLeft <= 0;

  @override
  void dispose() {
    _timer?.cancel();
    _otpCtrl.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────

  Future<void> _verify() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đủ 6 chữ số')),
      );
      return;
    }

    if (_isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mã OTP đã hết hạn. Vui lòng gửi lại.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final ok = await context.read<AuthProvider>().verifyResetOtp(
      widget.email,
      otp,
    );
    if (!mounted) return;

    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(email: widget.email, otp: otp),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<AuthProvider>().error ??
                'Mã OTP không hợp lệ hoặc đã hết hạn.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _resend() async {
    final ok = await context.read<AuthProvider>().forgotPassword(widget.email);
    if (!mounted) return;

    if (ok) {
      _startTimer(); // reset countdown
      _otpCtrl.clear();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Đã gửi lại mã OTP đến ${widget.email}'
              : (context.read<AuthProvider>().error ?? 'Gửi thất bại'),
        ),
        backgroundColor: ok ? Colors.green : Colors.redAccent,
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhập mã xác nhận'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.shield_outlined, size: 80, color: _kOrange),
                  const SizedBox(height: 20),
                  const Text(
                    'Xác nhận OTP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Nhập mã OTP 6 chữ số đã gửi đến:\n${widget.email}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  // ── Countdown badge ──────────────────────────────────
                  _CountdownBadge(
                    timerLabel: _timerLabel,
                    isExpired: _isExpired,
                    totalSeconds: _otpTtlSeconds,
                    secondsLeft: _secondsLeft,
                  ),

                  const SizedBox(height: 28),

                  // ── OTP input ────────────────────────────────────────
                  TextField(
                    controller: _otpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      fontSize: 32,
                      letterSpacing: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      hintText: '------',
                      hintStyle: TextStyle(
                        // Fixed: dùng withValues thay vì withOpacity (deprecated)
                        color: Colors.white.withValues(alpha: 0.2),
                        fontSize: 32,
                        letterSpacing: 10,
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFF2C2C2C),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _kOrange, width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Verify button ────────────────────────────────────
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kOrange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: (isLoading || _isExpired) ? null : _verify,
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Xác nhận',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),

                  const SizedBox(height: 16),

                  // ── Resend button ────────────────────────────────────
                  TextButton(
                    onPressed: isLoading ? null : _resend,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white60,
                    ),
                    child: const Text('Chưa nhận được mã? Gửi lại'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Countdown badge widget ───────────────────────────────────────────────────

class _CountdownBadge extends StatelessWidget {
  final String timerLabel;
  final bool isExpired;
  final int totalSeconds;
  final int secondsLeft;

  const _CountdownBadge({
    required this.timerLabel,
    required this.isExpired,
    required this.totalSeconds,
    required this.secondsLeft,
  });

  @override
  Widget build(BuildContext context) {
    final progress = secondsLeft / totalSeconds;
    final color = isExpired
        ? Colors.red
        : secondsLeft <= 60
        ? Colors.orange
        : _kOrange;

    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 5,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              Center(
                child: Text(
                  isExpired ? 'Hết\nhạn' : timerLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: isExpired ? 11 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isExpired ? 'Mã OTP đã hết hạn' : 'Mã có hiệu lực trong $timerLabel',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isExpired ? Colors.red : Colors.white38,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
