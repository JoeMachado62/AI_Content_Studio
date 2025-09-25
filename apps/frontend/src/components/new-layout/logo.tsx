'use client';
import Image from 'next/image';

export const Logo = () => {
  return (
    <div className="flex items-center">
      <Image
        src="/ai-content-studio-logo.png"
        alt="AI Content Studio"
        width={360}
        height={120}
        className="mt-[8px]"
        priority
      />
    </div>
  );
};
