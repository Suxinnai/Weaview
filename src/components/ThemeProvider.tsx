import React, { createContext, useContext, useState, useEffect } from 'react';

export type FontFamily = 'sans' | 'serif';
export type ThemeMode = 'light' | 'dark' | 'system';

export interface ThemeState {
  backgroundColor?: string;
  textColor?: string;
  fontFamily?: FontFamily;
  accentColors?: [string, string];
  isDark?: boolean; // legacy override, or maybe we leave it, but prefer resolvedTheme
}

const defaultTheme: ThemeState = {
  backgroundColor: '', 
  textColor: '',
  fontFamily: 'sans',
  accentColors: ['#B5EAEA', '#E2F0CB'],
  isDark: false,
};

interface ThemeContextType {
  theme: ThemeState;
  setTheme: (updates: Partial<ThemeState>) => void;
  resetTheme: () => void;
  themeUpdateKey: number;
  themeMode: ThemeMode;
  setThemeMode: (mode: ThemeMode) => void;
  resolvedTheme: 'light' | 'dark';
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setThemeState] = useState<ThemeState>(defaultTheme);
  const [themeUpdateKey, setThemeUpdateKey] = useState(0);
  const [themeMode, setThemeMode] = useState<ThemeMode>('system');
  const [resolvedTheme, setResolvedTheme] = useState<'light' | 'dark'>('light');

  useEffect(() => {
    const updateResolvedTheme = () => {
      let isDark = false;
      if (themeMode === 'dark') {
        isDark = true;
      } else if (themeMode === 'system') {
        isDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
      }
      
      setResolvedTheme(isDark ? 'dark' : 'light');
      
      // We can also override document body dark class
      if (isDark) {
        document.documentElement.classList.add('dark');
      } else {
        document.documentElement.classList.remove('dark');
      }
    };

    updateResolvedTheme();

    if (themeMode === 'system') {
      const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
      const listener = () => updateResolvedTheme();
      mediaQuery.addEventListener('change', listener);
      return () => mediaQuery.removeEventListener('change', listener);
    }
  }, [themeMode]);

  const setTheme = (updates: Partial<ThemeState>) => {
    setThemeState((prev) => ({ ...prev, ...updates }));
    setThemeUpdateKey(prev => prev + 1);
  };

  const resetTheme = () => {
    setThemeState(defaultTheme);
  };

  useEffect(() => {
    // Apply styling to document body based on the theme
    if (theme.backgroundColor) {
      document.body.style.backgroundColor = theme.backgroundColor;
    } else {
      document.body.style.backgroundColor = '';
    }

    if (theme.textColor) {
      document.body.style.color = theme.textColor;
    } else {
      document.body.style.color = '';
    }

    if (theme.fontFamily === 'serif') {
      document.body.style.fontFamily = 'var(--font-serif)';
    } else {
      document.body.style.fontFamily = 'var(--font-sans)';
    }
  }, [theme]);

  // CSS variables for inline style overwrites
  const style = {
    '--theme-bg': theme.backgroundColor || 'var(--color-weave-base)',
    '--theme-text': theme.textColor || 'var(--color-weave-text)',
    '--theme-accent-1': theme.accentColors?.[0] || 'var(--color-weave-accent-1)',
    '--theme-accent-2': theme.accentColors?.[1] || 'var(--color-weave-accent-2)',
  } as React.CSSProperties;

  return (
    <ThemeContext.Provider value={{ theme, setTheme, resetTheme, themeUpdateKey, themeMode, setThemeMode, resolvedTheme }}>
      <div style={style} className={`min-h-screen transition-colors duration-1000 ease-[cubic-bezier(0.22,1,0.36,1)] ${resolvedTheme === 'dark' ? 'dark' : ''}`}>
        {children}
      </div>
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  const context = useContext(ThemeContext);
  if (context === undefined) {
    throw new Error('useTheme must be used within a ThemeProvider');
  }
  return context;
}
