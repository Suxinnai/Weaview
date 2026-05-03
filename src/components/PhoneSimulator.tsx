import React, { useEffect, useState } from 'react';
import { useTheme } from './ThemeProvider';

export function PhoneSimulator({ children }: { children: React.ReactNode }) {
  const { theme } = useTheme();
  const [scale, setScale] = useState(1);
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    const handleResize = () => {
      setIsMobile(window.innerWidth < 640);
      const vh = window.innerHeight;
      if (vh < 892) {
        setScale(vh / 892);
      } else {
        setScale(1);
      }
    };
    
    handleResize();
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  if (isMobile) {
    return <div className="w-full h-full min-h-[100dvh] flex flex-col">{children}</div>;
  }

  return (
    <div className="flex items-center justify-center w-full min-h-screen transition-colors duration-1000 overflow-hidden relative">
      {/* Background Dimmer */}
      <div className="absolute inset-0 bg-black/10 dark:bg-black/40 backdrop-blur-3xl z-0 transition-colors duration-1000"></div>
      
      {/* Phone Hardware Container */}
      <div 
        className="relative shadow-2xl rounded-[55px] border-[14px] border-[#0f0f0f] overflow-hidden flex flex-col origin-center z-10 box-content"
        style={{
          width: '393px',
          height: '852px',
          transform: `scale(${scale})`,
          backgroundColor: theme.backgroundColor || 'var(--color-weave-base)',
        }}
      >
        {/* Hardware Buttons */}
        <div className="absolute top-[115px] -left-[16px] w-[3px] h-[32px] bg-[#0f0f0f] rounded-l-[2px]"></div>
        <div className="absolute top-[175px] -left-[16px] w-[3px] h-[62px] bg-[#0f0f0f] rounded-l-[2px]"></div>
        <div className="absolute top-[195px] -right-[16px] w-[3px] h-[95px] bg-[#0f0f0f] rounded-r-[2px]"></div>

        {/* Dynamic Island */}
        <div className="absolute top-3 left-1/2 -translate-x-1/2 w-[120px] h-[36px] bg-[#0F0F0F] rounded-full z-50 flex items-center justify-end px-3 shadow-[0_4px_10px_rgba(0,0,0,0.1)]">
          <div className="w-3 h-3 rounded-full bg-[#1A1A1A] mr-0.5 shadow-[inset_0_0_2px_rgba(255,255,255,0.2)] border border-white/5 relative">
             <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[4px] h-[4px] bg-blue-900/40 rounded-full blur-[1px]"></div>
          </div>
        </div>

        {/* Status Bar */}
        <div className="absolute top-0 left-0 w-full h-[50px] flex items-center justify-between px-7 z-40 pointer-events-none" style={{ color: theme.textColor }}>
          <span className="text-[15px] font-semibold tracking-tight mt-1 ml-1 opacity-90">9:41</span>
          <div className="flex items-center gap-1.5 mt-1 opacity-80">
            {/* Cellular */}
            <div className="flex items-end gap-[2px] h-[11px] mb-0.5">
              <div className="w-[3px] h-[4.5px] bg-current rounded-[1px]"></div>
              <div className="w-[3px] h-[6.5px] bg-current rounded-[1px]"></div>
              <div className="w-[3px] h-[8.5px] bg-current rounded-[1px]"></div>
              <div className="w-[3px] h-[10.5px] bg-current rounded-[1px]"></div>
            </div>
            {/* Wifi */}
            <svg className="w-4 h-4 ml-0.5" viewBox="0 0 24 24" fill="currentColor">
               <path d="M12 20.5C13.5 20.5 14.5 19.5 14.5 18C14.5 16.5 13.5 15.5 12 15.5C10.5 15.5 9.5 16.5 9.5 18C9.5 19.5 10.5 20.5 12 20.5ZM12 12C15.5 12 18.5 13.5 20.5 15.5L22 14C19.5 11.5 16 10 12 10C8 10 4.5 11.5 2 14L3.5 15.5C5.5 13.5 8.5 12 12 12ZM12 5C17.5 5 22 7 25 10L27 8C23.5 4.5 18 2.5 12 2.5C6 2.5 0.5 4.5 -3 8L-1 10C2 7 6.5 5 12 5Z"/>
            </svg>
            {/* Battery */}
            <div className="ml-0.5 w-[23px] h-[11.5px] border border-current rounded-[4px] p-[1.5px] relative flex items-center opacity-90">
              <div className="bg-current h-full w-[15px] rounded-[1.5px]"></div>
              <div className="absolute -right-[3.5px] top-1/2 -translate-y-1/2 w-[2px] h-[4px] bg-current opacity-60 rounded-r-full"></div>
            </div>
          </div>
        </div>

        {/* App Content */}
        <div 
          className="w-full h-full relative overflow-hidden flex flex-col z-10"
          style={{
            '--safe-area-top': '54px',
            '--safe-area-bottom': '34px',
          } as React.CSSProperties}
        >
          {children}
        </div>

        {/* Home Indicator */}
        <div className="absolute bottom-2 left-1/2 -translate-x-1/2 w-[135px] h-[5px] bg-[#111] dark:bg-white rounded-full z-50 opacity-50"></div>
      </div>
    </div>
  );
}
