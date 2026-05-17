/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,

  allowedDevOrigins: [
    '*.ngrok-free.dev',
    '*.ngrok.app',
  ],
};

export default nextConfig;