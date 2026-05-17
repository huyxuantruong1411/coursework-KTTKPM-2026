"use client";

import React, { useState } from 'react';
import { Loader2, Languages } from 'lucide-react';
import { Button } from '@/components/ui/Button';

interface TranslatedImageProps {
    imageUrl: string;
    className?: string;
    alt?: string;
}

export function TranslatedImage({ imageUrl, className, alt = "Manga Page" }: TranslatedImageProps) {
    const [imgSrc, setImgSrc] = useState<string>(imageUrl);
    const [isTranslating, setIsTranslating] = useState<boolean>(false);

    const handleTranslate = async () => {
        setIsTranslating(true);
        try {
            // Gọi API Backend vừa tạo
            const response = await fetch('/api/v1/translate/page', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ image_url: imageUrl, target_lang: 'vi' })
            });

            if (!response.ok) throw new Error("Translation failed");

            // Nhận blob hình ảnh đã được vẽ chữ tiếng việt
            const blob = await response.blob();
            const translatedUrl = URL.createObjectURL(blob);
            setImgSrc(translatedUrl); // Đổi src của ảnh hiện tại thành ảnh đã dịch
        } catch (error) {
            console.error(error);
            // Hiển thị thông báo lỗi (có thể dùng react-hot-toast của bạn)
            alert("Có lỗi xảy ra khi dịch trang này.");
        } finally {
            setIsTranslating(false);
        }
    };

    return (
        <div className={`relative group inline-block w-full ${className || ''}`}>
            {/* Ảnh truyện */}
            <img src={imgSrc} alt={alt} className="w-full h-auto object-contain transition-all" loading="lazy" />

            {/* Nút Dịch nổi lên khi rê chuột (Hover) */}
            <div className="absolute top-4 right-4 opacity-0 group-hover:opacity-100 transition-opacity duration-200">
                <Button
                    onClick={handleTranslate}
                    disabled={isTranslating}
                    className="bg-black/70 hover:bg-black text-white shadow-lg backdrop-blur-sm"
                    size="sm"
                >
                    {isTranslating ? (
                        <Loader2 className="animate-spin w-4 h-4 mr-2" />
                    ) : (
                        <Languages className="w-4 h-4 mr-2" />
                    )}
                    {isTranslating ? "Đang dịch..." : "Dịch trang"}
                </Button>
            </div>
        </div>
    );
}