import React, { useState, useRef } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { 
  Settings, X, Moon, Sun, Monitor, UserCircle, 
  Cpu, Key, Database, Info, ChevronRight, Plus, 
  Globe, Mic, Cloud, Layers, Trash2, Edit2,
  Eye, Image as ImageIcon, Wrench, Brain, Loader2, Check, MessageSquare
} from 'lucide-react';
import { useTheme } from './ThemeProvider';

interface SettingsSheetProps {
  isOpen: boolean;
  onClose: () => void;
  systemPrompt?: string;
  setSystemPrompt?: (val: string) => void;
  emotionEnabled?: boolean;
  setEmotionEnabled?: (val: boolean) => void;
  globalMemoryEnabled?: boolean;
  setGlobalMemoryEnabled?: (val: boolean) => void;
  referenceHistoryEnabled?: boolean;
  setReferenceHistoryEnabled?: (val: boolean) => void;
  assistantAvatar?: string;
  setAssistantAvatar?: (val: string) => void;
  userAvatar?: string;
  setUserAvatar?: (val: string) => void;
  userName?: string;
  setUserName?: (val: string) => void;
}

export function SettingsSheet({ 
  isOpen, 
  onClose, 
  systemPrompt = '', 
  setSystemPrompt, 
  emotionEnabled = true, 
  setEmotionEnabled,
  globalMemoryEnabled = true,
  setGlobalMemoryEnabled,
  referenceHistoryEnabled = true,
  setReferenceHistoryEnabled,
  assistantAvatar = '',
  setAssistantAvatar,
  userAvatar = '',
  setUserAvatar,
  userName = '织梦者',
  setUserName
}: SettingsSheetProps) {
  const { themeMode, setThemeMode, resolvedTheme } = useTheme();
  const [activeTab, setActiveTab] = useState<'general' | 'providers' | 'models' | 'services' | 'data' | 'about'>('general');
  const [subView, setSubView] = useState<'main' | 'system_prompt' | 'memory_management' | 'provider_config' | 'model_role_config' | 'search_engine_config' | 'tts_config'>('main');
  const [selectedProvider, setSelectedProvider] = useState('');
  const [customProviderName, setCustomProviderName] = useState('');
  const [providerApiKey, setProviderApiKey] = useState('');
  const [providerBaseUrl, setProviderBaseUrl] = useState('');
  const [testStatus, setTestStatus] = useState<'idle' | 'loading' | 'success' | 'error'>('idle');
  const [testMessage, setTestMessage] = useState('');
  const [pullStatus, setPullStatus] = useState<'idle' | 'loading' | 'success' | 'error'>('idle');
  const [pullMessage, setPullMessage] = useState('');
  const [providerTab, setProviderTab] = useState<'config' | 'models'>('config');
  const [providerModels, setProviderModels] = useState<{id: string, name: string, capabilities: string[]}[]>([]);
  const [showPullModal, setShowPullModal] = useState(false);
  const [showTestModal, setShowTestModal] = useState(false);
  const [isTestModelDropdownOpen, setIsTestModelDropdownOpen] = useState(false);
  const [testModelId, setTestModelId] = useState('');
  const [fetchedModels, setFetchedModels] = useState<{id: string, name: string, capabilities: string[]}[]>([]);
  const [selectedModelsToPull, setSelectedModelsToPull] = useState<string[]>([]);
  const [editingModel, setEditingModel] = useState<{id: string, name: string, capabilities: string[]} | null>(null);
  const [editingRole, setEditingRole] = useState<string | null>(null);

  const DEFAULT_ROLES = {
    chat: { name: '主对话模型', desc: '用于处理主要对话和生成内容', defaultPrompt: '你是一个有用、有条理、有创造力的人工智能助手。' },
    title: { name: '标题总结模型', desc: '用于生成历史记录标题 (需要快速)', defaultPrompt: '请用不超过10个字概括以下对话的核心内容，直接输出标题，不需要前缀。' },
    suggest: { name: '聊天建议模型', desc: '生成后续对话建议', defaultPrompt: '根据对话历史，简明扼要地提供3个用户可能想说的简短后续问题。' },
    translate: { name: '翻译模型', desc: '用于语言翻译功能', defaultPrompt: '你是一个专业的翻译人员，请将输入的文本翻译成目标语言，保持原意，语言流畅。' }
  };

  const [modelAssignments, setModelAssignments] = useState<Record<string, { provider: string, model: string, prompt: string }>>(() => {
    const saved = localStorage.getItem('ai_model_assignments');
    if (saved) return JSON.parse(saved);
    return {
      chat: { provider: '', model: '', prompt: DEFAULT_ROLES.chat.defaultPrompt },
      title: { provider: '', model: '', prompt: DEFAULT_ROLES.title.defaultPrompt },
      suggest: { provider: '', model: '', prompt: DEFAULT_ROLES.suggest.defaultPrompt },
      translate: { provider: '', model: '', prompt: DEFAULT_ROLES.translate.defaultPrompt },
    };
  });

  const [roleDraft, setRoleDraft] = useState<{ provider: string, model: string, prompt: string }>({ provider: '', model: '', prompt: '' });
  const [isRoleProviderDropdownOpen, setIsRoleProviderDropdownOpen] = useState(false);
  const [isRoleModelDropdownOpen, setIsRoleModelDropdownOpen] = useState(false);

  const SEARCH_ENGINES = [
    { id: 'tavily', name: 'Tavily AI' },
    { id: 'brave', name: 'Brave Search' },
    { id: 'perplexity', name: 'Perplexity' },
  ] as const;

  const [searchConfig, setSearchConfig] = useState<{ active: string, keys: Record<string, string> }>(() => {
    const saved = localStorage.getItem('ai_search_config');
    if (saved) return JSON.parse(saved);
    return { active: 'tavily', keys: {} };
  });

  const [activeTtsId, setActiveTtsId] = useState<string>(() => {
    return localStorage.getItem('ai_active_tts_id') || 'system';
  });
  const [ttsProvidersConfig, setTtsProvidersConfig] = useState<{ id: string, type: string, name: string, apiKey: string, baseUrl: string, model: string, voice: string }[]>(() => {
    const saved = localStorage.getItem('ai_tts_providers');
    if (saved) {
      const parsed = JSON.parse(saved);
      const updated = parsed.map((t: any) => t.id === 'xiaomi' && t.name === 'Xiaomi MiM TTS' ? { ...t, name: 'Xiaomi MiMo TTS' } : t);
      return updated;
    }
    return [
      { id: 'xiaomi', type: 'xiaomi', name: 'Xiaomi MiMo TTS', apiKey: '', baseUrl: '', model: '', voice: '' }
    ];
  });
  const [editingTtsId, setEditingTtsId] = useState<string | null>(null);
  const [ttsDraft, setTtsDraft] = useState<{ id: string, type: string, name: string, apiKey: string, baseUrl: string, model: string, voice: string }>({ id: '', type: 'openai', name: '', apiKey: '', baseUrl: '', model: '', voice: '' });

  const [modelSearchQuery, setModelSearchQuery] = useState('');
  const [deletingProvider, setDeletingProvider] = useState<string | null>(null);

  const fileInputRef = useRef<HTMLInputElement>(null);
  const userFileInputRef = useRef<HTMLInputElement>(null);
  const longPressTimerRef = useRef<NodeJS.Timeout | null>(null);
  const isLongPressRef = useRef(false);
  const touchStartPosRef = useRef({ x: 0, y: 0 });

  const handleAvatarUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onloadend = () => {
        const base64String = reader.result as string;
        setAssistantAvatar?.(base64String);
      };
      reader.readAsDataURL(file);
    }
  };

  const handleUserAvatarUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onloadend = () => {
        const base64String = reader.result as string;
        setUserAvatar?.(base64String);
      };
      reader.readAsDataURL(file);
    }
  };

  const [newMemory, setNewMemory] = useState('');

  const [memories, setMemories] = useState<string[]>(() => {
    const saved = localStorage.getItem('ai_memories');
    if (saved) return JSON.parse(saved);
    return [
      '用户喜欢使用科幻和诗意的语言进行交流',
      '常用的主题包括：未来主义、设计、哲学'
    ];
  });

  const handleDeleteMemory = (index: number) => {
    const newMemories = memories.filter((_, i) => i !== index);
    setMemories(newMemories);
    localStorage.setItem('ai_memories', JSON.stringify(newMemories));
  };

  const handleClearMemories = () => {
    setMemories([]);
    localStorage.setItem('ai_memories', JSON.stringify([]));
  };

  const handleAddMemory = () => {
    if (!newMemory.trim()) return;
    const newMemories = [newMemory, ...memories];
    setMemories(newMemories);
    localStorage.setItem('ai_memories', JSON.stringify(newMemories));
    setNewMemory('');
  };

  const handleClose = () => {
    if (subView === 'provider_config') {
      handleSaveProviderConfig();
    }
    onClose();
    setTimeout(() => setSubView('main'), 300); // reset after animation
  };

  const updateProviderModelsAndSync = (nextModels: any[]) => {
    setProviderModels(nextModels);
    setProviders(prevProviders => {
      const targetName = selectedProvider || customProviderName.trim();
      if (!targetName) return prevProviders;
      
      const exists = prevProviders.some(p => p.name === targetName);
      if (!exists) return prevProviders;
      
      const nextProviders = prevProviders.map(p => 
        p.name === targetName ? { ...p, models: nextModels } : p
      );
      localStorage.setItem('ai_providers', JSON.stringify(nextProviders));
      return nextProviders;
    });
  };

  const tabs = [
    { id: 'general', label: '通用', icon: Settings },
    { id: 'providers', label: '提供商', icon: Cloud },
    { id: 'models', label: '默认模型', icon: Cpu },
    { id: 'services', label: '扩展服务', icon: Layers },
    { id: 'data', label: '数据管理', icon: Database },
    { id: 'about', label: '关于织境', icon: Info },
  ] as const;

  const [providers, setProviders] = useState<{name: string, status: string, current: boolean, color: string, apiKey?: string, baseUrl?: string, models?: {id: string, name: string, capabilities: string[]}[]}[]>(() => {
    try {
      const saved = localStorage.getItem('ai_providers');
      if (saved) return JSON.parse(saved);
    } catch(e) {}
    return [
      { name: 'OpenAI', status: '已连接', current: false, color: 'bg-emerald-500' },
      { name: 'Gemini', status: '使用中', current: true, color: 'bg-blue-500' },
      { name: 'Anthropic', status: '未配置', current: false, color: 'bg-amber-600' },
      { name: 'DeepSeek', status: '已连接', current: false, color: 'bg-blue-600' },
      { name: 'Kimi', status: '未配置', current: false, color: 'bg-gray-600' },
      { name: 'MiniMax', status: '未配置', current: false, color: 'bg-purple-500' },
      { name: 'Grok', status: '未配置', current: false, color: 'bg-black dark:bg-white' },
    ];
  });

  const handleSaveProviderConfig = () => {
    let updatedProviders = [...providers];
    let finalStatus = providerApiKey ? '已连接' : '未配置';
    if (selectedProvider) {
      updatedProviders = providers.map(p => {
        if (p.name === selectedProvider) {
          return { ...p, apiKey: providerApiKey, baseUrl: providerBaseUrl, status: finalStatus, models: providerModels };
        }
        return p;
      });
      setProviders(updatedProviders);
    } else if (customProviderName.trim()) {
      const newProvider = { 
        name: customProviderName.trim(), 
        status: finalStatus, 
        current: false, 
        color: 'bg-indigo-500',
        apiKey: providerApiKey,
        baseUrl: providerBaseUrl,
        models: providerModels
      };
      updatedProviders = [...providers, newProvider];
      setProviders(updatedProviders);
    }
    localStorage.setItem('ai_providers', JSON.stringify(updatedProviders));
    setSubView('main');
  };

  const handleEnableProvider = () => {
    if (!providerApiKey) return;
    const targetName = selectedProvider || customProviderName.trim();
    if (!targetName) return;
    
    let updatedProviders = [...providers];
    const existing = updatedProviders.find(p => p.name === targetName);
    if (!existing) {
      updatedProviders.push({ 
        name: targetName, 
        status: '已连接', 
        current: true, 
        color: 'bg-indigo-500',
        apiKey: providerApiKey,
        baseUrl: providerBaseUrl,
        models: providerModels
      });
    }
    updatedProviders = updatedProviders.map(p => ({
      ...p,
      current: p.name === targetName,
      status: p.name === targetName ? '使用中' : (p.apiKey ? '已连接' : '未配置'),
      ...(p.name === targetName ? { apiKey: providerApiKey, baseUrl: providerBaseUrl, models: providerModels } : {})
    }));
    setProviders(updatedProviders);
    localStorage.setItem('ai_providers', JSON.stringify(updatedProviders));
    setSubView('main');
  };

  const handleProviderPointerDown = (e: React.PointerEvent, providerName: string) => {
    try { e.currentTarget.setPointerCapture(e.pointerId); } catch(err) {}
    touchStartPosRef.current = { x: e.clientX, y: e.clientY };
    isLongPressRef.current = false;
    longPressTimerRef.current = setTimeout(() => {
      isLongPressRef.current = true;
      try { navigator.vibrate?.(50); } catch(err){}
      setDeletingProvider(providerName);
    }, 600);
  };

  const handleProviderPointerMove = (e: React.PointerEvent) => {
    if (!longPressTimerRef.current) return;
    const dx = e.clientX - touchStartPosRef.current.x;
    const dy = e.clientY - touchStartPosRef.current.y;
    if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
      clearTimeout(longPressTimerRef.current);
      longPressTimerRef.current = null;
    }
  };

  const handleProviderPointerUpOrLeave = (e: React.PointerEvent) => {
    try { e.currentTarget.releasePointerCapture(e.pointerId); } catch(err) {}
    if (longPressTimerRef.current) {
      clearTimeout(longPressTimerRef.current);
      longPressTimerRef.current = null;
    }
  };

  return (
    <AnimatePresence>
      {isOpen && (
        <>
          <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={handleClose}
            className="absolute inset-0 bg-black/20 dark:bg-black/60 backdrop-blur-sm z-50 transition-opacity duration-300"
          />
          <motion.div
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            transition={{ type: 'spring', damping: 28, stiffness: 250 }}
            className="absolute bottom-0 left-0 w-full h-[85%] sm:h-[80%] bg-[#f8f9fa] dark:bg-[#121415] rounded-t-[32px] md:rounded-t-[40px] z-50 flex flex-col shadow-[0_-20px_60px_rgba(0,0,0,0.15)] dark:shadow-[0_-20px_60px_rgba(0,0,0,0.4)] outline-none overflow-hidden"
          >
            {/* Drag Handle & Header */}
            <div className="w-full shrink-0 bg-[#f8f9fa]/80 dark:bg-[#121415]/80 backdrop-blur-md z-10 sticky top-0 border-b border-black/5 dark:border-white/5 rounded-t-[32px] md:rounded-t-[40px]">
              <div className="w-full flex items-center justify-center pt-3 pb-2 cursor-pointer" onClick={handleClose}>
                <div className="w-12 h-1.5 bg-black/10 dark:bg-white/20 rounded-full"></div>
              </div>
              <div className="px-6 flex items-center justify-center pb-4 relative min-h-[44px]">
                {subView === 'main' ? (
                    <h2 className="text-xl font-medium tracking-wide">设置</h2>
                ) : (
                  <>
                    <button onClick={() => {
                      if (subView === 'provider_config') {
                        handleSaveProviderConfig();
                      } else if (subView === 'model_role_config') {
                        setSubView('main');
                        setEditingRole(null);
                        setIsRoleProviderDropdownOpen(false);
                        setIsRoleModelDropdownOpen(false);
                      } else if (subView === 'tts_config') {
                        setSubView('main');
                        setEditingTtsId(null);
                      } else {
                        setSubView('main');
                      }
                    }} className="absolute left-6 p-2 -ml-2 rounded-full hover:bg-black/5 dark:hover:bg-white/5 transition-colors flex items-center gap-1 z-10">
                      <ChevronRight className="w-5 h-5 opacity-60 rotate-180" />
                      <span className="text-[15px] font-medium opacity-80">返回</span>
                    </button>
                    <h2 className="text-[17px] font-medium tracking-wide">
                      {subView === 'system_prompt' ? '全局系统提示词' : subView === 'memory_management' ? '记忆管理' : subView === 'provider_config' ? '供应商配置' : subView === 'model_role_config' && editingRole ? DEFAULT_ROLES[editingRole as keyof typeof DEFAULT_ROLES].name : subView === 'search_engine_config' ? '搜索服务配置' : subView === 'tts_config' ? '语音服务配置' : ''}
                    </h2>
                  </>
                )}
              </div>
              
              {/* Tab Navigation */}
              {subView === 'main' && (
                <div 
                className="px-4 pb-2 w-full overflow-x-auto no-scrollbar touch-pan-x cursor-grab active:cursor-grabbing select-none"
                onMouseDown={(e) => {
                  const target = e.currentTarget;
                  target.dataset.isDown = 'true';
                  target.dataset.startX = e.pageX.toString();
                  target.dataset.scrollLeft = target.scrollLeft.toString();
                  target.dataset.dragged = 'false';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.dataset.isDown = 'false';
                }}
                onMouseUp={(e) => {
                  e.currentTarget.dataset.isDown = 'false';
                }}
                onMouseMove={(e) => {
                  const target = e.currentTarget;
                  if (target.dataset.isDown !== 'true') return;
                  e.preventDefault();
                  target.dataset.dragged = 'true';
                  const startX = parseFloat(target.dataset.startX || '0');
                  const scrollLeft = parseFloat(target.dataset.scrollLeft || '0');
                  const walk = (e.pageX - startX) * 1.5; 
                  target.scrollLeft = scrollLeft - walk;
                }}
                onWheel={(e) => {
                  if (e.deltaY !== 0) {
                    e.currentTarget.scrollLeft += e.deltaY;
                  }
                }}
                onClickCapture={(e) => {
                  if (e.currentTarget.dataset.dragged === 'true') {
                    e.stopPropagation();
                    e.currentTarget.dataset.dragged = 'false';
                  }
                }}
              >
                <div className="flex gap-2 w-max pr-8">
                  {tabs.map(tab => {
                    const Icon = tab.icon;
                    const isActive = activeTab === tab.id;
                    return (
                      <button
                        key={tab.id}
                        onClick={() => setActiveTab(tab.id)}
                        className={`px-4 py-2 rounded-full flex items-center gap-2 text-[13px] inline-flex font-medium transition-all ${
                          isActive 
                            ? 'bg-black text-white dark:bg-white dark:text-black shadow-md' 
                            : 'bg-black/5 dark:bg-white/5 text-[var(--theme-text)] opacity-70 hover:opacity-100'
                        }`}
                      >
                        <Icon className="w-4 h-4" />
                        {tab.label}
                      </button>
                    );
                  })}
                </div>
              </div>
              )}
            </div>

            {/* Scrollable Content Area */}
            <div className="flex-1 overflow-y-auto px-6 py-6 pb-safe">
              {subView === 'main' && activeTab === 'general' && (
                <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500">
                  {/* Theme Settings */}
                  <section>
                    <h3 className="text-[12px] font-bold tracking-widest uppercase opacity-40 mb-3 px-1">外观与主题</h3>
                    <div className="bg-white dark:bg-white/5 rounded-[24px] overflow-hidden border border-black/5 dark:border-white/5 p-2 flex gap-2">
                       <button onClick={() => setThemeMode('light')} className={`flex-1 flex flex-col items-center justify-center py-4 rounded-2xl transition-all ${themeMode === 'light' ? 'bg-black/5 dark:bg-white/10 shadow-inner' : 'opacity-60 hover:bg-black/5 dark:hover:bg-white/5'}`}>
                         <Sun className="w-6 h-6 mb-2" />
                         <span className="text-[12px] font-medium">浅色</span>
                       </button>
                       <button onClick={() => setThemeMode('dark')} className={`flex-1 flex flex-col items-center justify-center py-4 rounded-2xl transition-all ${themeMode === 'dark' ? 'bg-black/5 dark:bg-white/10 shadow-inner' : 'opacity-60 hover:bg-black/5 dark:hover:bg-white/5'}`}>
                         <Moon className="w-6 h-6 mb-2" />
                         <span className="text-[12px] font-medium">深色</span>
                       </button>
                       <button onClick={() => setThemeMode('system')} className={`flex-1 flex flex-col items-center justify-center py-4 rounded-2xl transition-all ${themeMode === 'system' ? 'bg-black/5 dark:bg-white/10 shadow-inner' : 'opacity-60 hover:bg-black/5 dark:hover:bg-white/5'}`}>
                         <Monitor className="w-6 h-6 mb-2" />
                         <span className="text-[12px] font-medium">跟随系统</span>
                       </button>
                    </div>
                  </section>

                  {/* User Profile Settings */}
                  <section>
                    <h3 className="text-[12px] font-bold tracking-widest uppercase opacity-40 mb-3 px-1">个人资料</h3>
                    <div className="bg-white dark:bg-white/5 rounded-[24px] overflow-hidden border border-black/5 dark:border-white/5">
                      <div className="p-4 px-5 border-b border-black/5 dark:border-white/5 flex items-center justify-between">
                        <div className="flex flex-col">
                          <span className="text-[15px] font-medium">昵称</span>
                          <span className="text-[12px] opacity-50">你的专属代号</span>
                        </div>
                        <input
                          type="text"
                          value={userName}
                          onChange={(e) => setUserName?.(e.target.value)}
                          className="bg-black/5 dark:bg-white/5 border border-transparent focus:border-[var(--theme-accent-1)]/50 rounded-xl px-3 py-1.5 text-[14px] w-32 text-right outline-none transition-colors"
                          placeholder="织梦者"
                        />
                      </div>
                      <div 
                        onClick={() => userFileInputRef.current?.click()}
                        className="p-4 px-5 border-b border-black/5 dark:border-white/5 cursor-pointer hover:bg-black/[0.02] dark:hover:bg-white/[0.02] transition-colors flex items-center justify-between group"
                      >
                        <div className="flex flex-col">
                          <span className="text-[15px] font-medium">个人头像</span>
                          <span className="text-[12px] opacity-50">用于展示你的个人形象</span>
                        </div>
                        <div className="flex items-center gap-2">
                          <input 
                            type="file" 
                            accept="image/*" 
                            className="hidden" 
                            ref={userFileInputRef} 
                            onChange={handleUserAvatarUpload} 
                          />
                          {userAvatar && (
                            <button 
                              onClick={(e) => {
                                e.stopPropagation();
                                setUserAvatar?.('');
                              }}
                              className="p-1.5 rounded-full hover:bg-red-500/10 text-red-500/60 hover:text-red-500 transition-colors"
                            >
                              <Trash2 className="w-4 h-4" />
                            </button>
                          )}
                          <div className="w-10 h-10 shrink-0 rounded-full bg-[var(--theme-accent-1)]/20 flex items-center justify-center text-[var(--theme-accent-1)] overflow-hidden group-hover:ring-2 ring-black/5 dark:ring-white/5 transition-all">
                            {userAvatar ? (
                              <img src={userAvatar} alt="User Avatar" className="w-full h-full object-cover" />
                            ) : (
                              <UserCircle className="w-5 h-5 opacity-60" />
                            )}
                          </div>
                        </div>
                      </div>
                    </div>
                  </section>

                  {/* Persona Settings */}
                  <section>
                    <h3 className="text-[12px] font-bold tracking-widest uppercase opacity-40 mb-3 px-1">人设设置</h3>
                    <div className="bg-white dark:bg-white/5 rounded-[24px] overflow-hidden border border-black/5 dark:border-white/5">
                      <div 
                        onClick={() => setSubView('system_prompt')}
                        className="p-4 px-5 border-b border-black/5 dark:border-white/5 cursor-pointer hover:bg-black/[0.02] dark:hover:bg-white/[0.02] transition-colors flex items-center justify-between group"
                      >
                        <div className="flex items-center gap-3 w-full min-w-0 mr-4">
                          <div className="w-10 h-10 shrink-0 rounded-full bg-[var(--theme-accent-1)]/20 flex items-center justify-center text-[var(--theme-accent-1)] overflow-hidden">
                            {assistantAvatar ? (
                              <img src={assistantAvatar} alt="Assistant Avatar" className="w-full h-full object-cover" />
                            ) : (
                              <UserCircle className="w-6 h-6 text-[#10B981]" />
                            )}
                          </div>
                          <div className="flex flex-col min-w-0 flex-1">
                            <span className="text-[15px] font-medium truncate">全局系统提示词</span>
                            <span className="text-[12px] opacity-50 truncate w-full">{systemPrompt.replace(/\n/g, ' ')}</span>
                          </div>
                        </div>
                        <ChevronRight className="w-5 h-5 opacity-40 group-hover:opacity-100 transition-opacity shrink-0" />
                      </div>
                      <div 
                        onClick={() => fileInputRef.current?.click()}
                        className="p-4 px-5 border-b border-black/5 dark:border-white/5 cursor-pointer hover:bg-black/[0.02] dark:hover:bg-white/[0.02] transition-colors flex items-center justify-between group"
                      >
                        <div className="flex flex-col">
                          <span className="text-[15px] font-medium">助手头像</span>
                          <span className="text-[12px] opacity-50">自定义AI伙伴的形象</span>
                        </div>
                        <div className="flex items-center gap-2">
                          <input 
                            type="file" 
                            accept="image/*" 
                            className="hidden" 
                            ref={fileInputRef} 
                            onChange={handleAvatarUpload} 
                          />
                          {assistantAvatar && (
                            <button 
                              onClick={(e) => {
                                e.stopPropagation();
                                setAssistantAvatar?.('');
                              }}
                              className="p-1.5 rounded-full hover:bg-red-500/10 text-red-500/60 hover:text-red-500 transition-colors"
                            >
                              <Trash2 className="w-4 h-4" />
                            </button>
                          )}
                          <div className="w-8 h-8 rounded-full bg-black/5 dark:bg-white/5 flex items-center justify-center text-black/50 dark:text-white/50 group-hover:bg-[var(--theme-accent-1)]/10 group-hover:text-[var(--theme-accent-1)] transition-colors">
                             <Edit2 className="w-4 h-4" />
                          </div>
                        </div>
                      </div>
                      <div 
                        onClick={() => setEmotionEnabled?.(!emotionEnabled)}
                        className="p-4 px-5 border-b border-black/5 dark:border-white/5 cursor-pointer hover:bg-black/[0.02] dark:hover:bg-white/[0.02] transition-colors flex items-center justify-between group"
                      >
                        <div className="flex flex-col">
                          <span className="text-[15px] font-medium">情绪化回应</span>
                          <span className="text-[12px] opacity-50">梦境的感性程度</span>
                        </div>
                        <div className={`w-12 h-6 rounded-full relative p-0.5 transition-colors ${emotionEnabled ? 'bg-[#10B981]' : 'bg-black/10 dark:bg-white/10'}`}>
                          <div className={`w-5 h-5 rounded-full bg-white shadow-sm transition-transform ${emotionEnabled ? 'ml-auto' : 'mr-auto'}`}></div>
                        </div>
                      </div>
                      <div 
                        onClick={() => setSubView('memory_management')}
                        className="p-4 px-5 cursor-pointer hover:bg-black/[0.02] dark:hover:bg-white/[0.02] transition-colors flex items-center justify-between group"
                      >
                        <div className="flex flex-col">
                          <span className="text-[15px] font-medium">记忆管理</span>
                          <span className="text-[12px] opacity-50">查看或清除AI长效记忆</span>
                        </div>
                        <ChevronRight className="w-5 h-5 opacity-40 group-hover:opacity-100 transition-opacity shrink-0" />
                      </div>
                    </div>
                  </section>
                </div>
              )}

              {subView === 'main' && activeTab === 'providers' && (
                <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500">
                   <div className="flex items-center justify-between px-1">
                     <h3 className="text-[12px] font-bold tracking-widest uppercase opacity-40">模型提供商</h3>
                     <button 
                       onClick={() => {
                         setSelectedProvider('');
                         setCustomProviderName('');
                         setProviderApiKey('');
                         setProviderBaseUrl('');
                         setTestStatus('idle');
                         setPullStatus('idle');
                         setTestMessage('');
                         setPullMessage('');
                         setProviderTab('config');
                         setProviderModels([]);
                         setSubView('provider_config');
                       }}
                       className="text-[12px] text-[#10B981] font-medium flex items-center gap-1"
                     >
                       <Plus className="w-3 h-3" /> 自定义提供商
                     </button>
                   </div>
                   
                   <div className="grid grid-cols-2 lg:grid-cols-3 gap-3">
                     {providers.map((provider, i) => (
                       <div 
                         key={i} 
                         onClick={() => {
                           if (isLongPressRef.current) return;
                           setSelectedProvider(provider.name);
                           setProviderApiKey(provider.apiKey || '');
                           setProviderBaseUrl(provider.baseUrl || '');
                           setTestStatus('idle');
                           setPullStatus('idle');
                           setTestMessage('');
                           setPullMessage('');
                           setProviderTab('config');
                           setProviderModels(provider.models || []);
                           setSubView('provider_config');
                         }}
                         onPointerDown={(e) => handleProviderPointerDown(e, provider.name)}
                         onPointerMove={handleProviderPointerMove}
                         onPointerUp={handleProviderPointerUpOrLeave}
                         onPointerLeave={handleProviderPointerUpOrLeave}
                         onPointerCancel={handleProviderPointerUpOrLeave}
                         onContextMenu={(e) => {
                           e.preventDefault();
                           try { navigator.vibrate?.(50); } catch(err){}
                           setDeletingProvider(provider.name);
                         }}
                         className={`select-none p-4 rounded-[20px] border flex flex-col justify-between aspect-square cursor-pointer transition-all hover:scale-[1.02] active:scale-[0.98] ${
                         provider.current 
                          ? 'bg-white dark:bg-white/10 border-[var(--theme-accent-1)] shadow-lg shadow-[var(--theme-accent-1)]/10' 
                          : 'bg-white/50 dark:bg-white/5 border-black/5 dark:border-white/5 hover:border-black/10 dark:hover:border-white/10'
                       }`}>
                         <div className="flex justify-between items-start">
                           <div className={`w-2 h-2 rounded-full mt-1 ${provider.color}`}></div>
                           {provider.current && <div className="text-[10px] uppercase font-bold text-[var(--theme-accent-1)]">Current</div>}
                         </div>
                         <div className="min-w-0 w-full">
                           <div className="text-lg font-medium mb-1 truncate block w-full" title={provider.name}>{provider.name}</div>
                           <div className="text-[11px] opacity-50 flex items-center gap-1">
                             {provider.status === '已连接' || provider.status === '使用中' ? <div className="w-1.5 h-1.5 rounded-full bg-green-500"></div> : <div className="w-1.5 h-1.5 rounded-full bg-gray-400"></div>}
                             {provider.status}
                           </div>
                         </div>
                       </div>
                     ))}
                   </div>
                </div>
              )}

              {subView === 'main' && activeTab === 'models' && (
                <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500">
                  <h3 className="text-[12px] font-bold tracking-widest uppercase opacity-40 px-1">默认模型分配</h3>
                  
                  <div className="space-y-3">
                    {/* Model Assignment Cards */}
                    {Object.entries(DEFAULT_ROLES).map(([id, role]) => (
                      <div 
                        key={id} 
                        onClick={() => {
                          setEditingRole(id);
                          setRoleDraft({ ...modelAssignments[id] });
                          setSubView('model_role_config');
                        }}
                        className="bg-white dark:bg-white/5 p-4 rounded-[20px] border border-black/5 dark:border-white/5 flex items-center justify-between cursor-pointer hover:bg-black/[0.02] dark:hover:bg-white/[0.02] transition-colors group"
                      >
                         <div>
                           <div className="text-[15px] font-medium">{role.name}</div>
                           <div className="text-[12px] opacity-50 mt-0.5">{role.desc}</div>
                         </div>
                         <div className="flex items-center gap-2">
                           {modelAssignments[id].model ? (
                             <span className="text-[13px] text-[#10B981] bg-[#10B981]/10 px-3 py-1 rounded-full font-medium max-w-[120px] truncate">{modelAssignments[id].model}</span>
                           ) : (
                             <span className="text-[13px] opacity-40 px-3 py-1 rounded-full border border-black/10 dark:border-white/10">未分配</span>
                           )}
                           <ChevronRight className="w-4 h-4 opacity-30 group-hover:opacity-100 transition-opacity" />
                         </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {subView === 'main' && activeTab === 'services' && (
                <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500">
                  {/* Search Engine */}
                  <section>
                    <h3 className="text-[12px] font-bold tracking-widest uppercase opacity-40 mb-3 px-1 flex items-center gap-2">
                      <Globe className="w-3.5 h-3.5" /> 搜索服务
                    </h3>
                    <div className="bg-white dark:bg-white/5 rounded-[24px] overflow-hidden border border-black/5 dark:border-white/5">
                      <div 
                        className="p-4 px-5 border-b border-black/5 dark:border-white/5 cursor-pointer hover:bg-black/[0.02] dark:hover:bg-white/[0.02] transition-colors flex items-center justify-between"
                        onClick={() => setSubView('search_engine_config')}
                      >
                        <div className="flex flex-col">
                          <span className="text-[15px] font-medium">默认搜索引擎</span>
                          <span className="text-[12px] opacity-50 text-[var(--theme-accent-1)] truncate">正在使用: {SEARCH_ENGINES.find(e => e.id === searchConfig.active)?.name || searchConfig.active}</span>
                        </div>
                        <ChevronRight className="w-5 h-5 opacity-40" />
                      </div>
                      <div className="px-5 py-3 text-[12px] opacity-60 leading-relaxed bg-black/[0.01] dark:bg-white/[0.01]">
                        支持配置 Tavily, Brave, Perplexity 等联网搜索服务，为模型提供实时信息支持。
                      </div>
                    </div>
                  </section>

                  {/* TTS & Voice */}
                  <section>
                    <h3 className="text-[12px] font-bold tracking-widest uppercase opacity-40 mb-3 px-1 flex items-center gap-2">
                      <Mic className="w-3.5 h-3.5" /> 语音服务 (TTS)
                    </h3>
                    <div className="bg-white dark:bg-white/5 rounded-[24px] overflow-hidden border border-black/5 dark:border-white/5">
                      <div className="p-4 px-5 border-b border-black/5 dark:border-white/5 flex items-center justify-between">
                        <div className="flex flex-col">
                          <span className="text-[15px] font-medium">系统 TTS</span>
                          <span className="text-[12px] opacity-50">使用设备默认语音播报</span>
                        </div>
                         <div 
                           onClick={() => {
                             const val = activeTtsId === 'system' ? '' : 'system';
                             setActiveTtsId(val);
                             localStorage.setItem('ai_active_tts_id', val);
                           }}
                           className={`w-12 h-6 rounded-full relative p-0.5 transition-colors cursor-pointer ${activeTtsId === 'system' ? 'bg-[var(--theme-accent-1)]' : 'bg-black/10 dark:bg-white/10'}`}>
                          <div className={`w-5 h-5 rounded-full bg-white shadow-sm transition-transform ${activeTtsId === 'system' ? 'translate-x-6' : 'translate-x-0'}`}></div>
                        </div>
                      </div>
                      
                      {ttsProvidersConfig.map(tts => (
                        <div key={tts.id} className="p-4 px-5 border-b border-black/5 dark:border-white/5 flex items-center justify-between group">
                          <div 
                            onClick={() => {
                              setEditingTtsId(tts.id);
                              setTtsDraft({ ...tts });
                              setSubView('tts_config');
                            }}
                            className="flex flex-col flex-1 cursor-pointer"
                          >
                            <span className="text-[15px] font-medium flex items-center gap-2">
                              {tts.name}
                              <ChevronRight className="w-4 h-4 opacity-0 group-hover:opacity-40 transition-opacity" />
                            </span>
                            <span className="text-[12px] opacity-50">{tts.apiKey || tts.baseUrl ? (tts.model || tts.voice || '已配置') : '未配置'}</span>
                          </div>
                          
                           <div 
                             onClick={(e) => {
                               e.stopPropagation();
                               const val = activeTtsId === tts.id ? '' : tts.id;
                               setActiveTtsId(val);
                               localStorage.setItem('ai_active_tts_id', val);
                             }}
                             className={`w-12 h-6 rounded-full relative p-0.5 transition-colors cursor-pointer ml-4 ${activeTtsId === tts.id ? 'bg-[var(--theme-accent-1)]' : 'bg-black/10 dark:bg-white/10'}`}>
                            <div className={`w-5 h-5 rounded-full bg-white shadow-sm transition-transform ${activeTtsId === tts.id ? 'translate-x-6' : 'translate-x-0'}`}></div>
                          </div>
                        </div>
                      ))}
                      
                      <div 
                        className="p-4 px-5 cursor-pointer hover:bg-black/[0.02] dark:hover:bg-white/[0.02] transition-colors flex items-center justify-between text-[var(--theme-accent-1)]"
                        onClick={() => {
                          const newId = 'custom_' + Date.now();
                          setEditingTtsId(newId);
                          setTtsDraft({ id: newId, type: 'openai', name: '自定义 TTS', apiKey: '', baseUrl: '', model: '', voice: '' });
                          setSubView('tts_config');
                        }}
                      >
                        <span className="text-[14px] font-medium flex items-center gap-2"><Plus className="w-4 h-4"/> 添加自定义 TTS 提供商</span>
                      </div>
                    </div>
                  </section>
                </div>
              )}

              {subView === 'main' && activeTab === 'data' && (
                <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500">
                  <h3 className="text-[12px] font-bold tracking-widest uppercase opacity-40 px-1">本地数据存储</h3>
                  
                  <div className="bg-white dark:bg-white/5 rounded-[24px] overflow-hidden border border-black/5 dark:border-white/5 p-6">
                    <div className="flex items-end justify-between mb-2">
                       <span className="text-[32px] font-light tracking-tight">24<span className="text-lg opacity-50 ml-1 font-normal">MB</span></span>
                       <span className="text-[13px] opacity-50 mb-2">总已用空间</span>
                    </div>
                    
                    {/* Storage Bar */}
                    <div className="w-full h-3 rounded-full bg-black/5 dark:bg-white/5 overflow-hidden flex mb-6">
                      <div className="h-full bg-blue-500 w-[60%]"></div>
                      <div className="h-full bg-[var(--theme-accent-1)] w-[25%]"></div>
                      <div className="h-full bg-purple-500 w-[10%]"></div>
                    </div>
                    
                    {/* Storage Breakdown */}
                    <div className="space-y-3">
                      <div className="flex items-center justify-between text-[13px]">
                        <div className="flex items-center gap-2">
                          <div className="w-2 h-2 rounded-full bg-blue-500"></div>
                          <span className="opacity-80">对话记录</span>
                        </div>
                        <span className="font-medium">14.5 MB</span>
                      </div>
                      <div className="flex items-center justify-between text-[13px]">
                        <div className="flex items-center gap-2">
                          <div className="w-2 h-2 rounded-full bg-[var(--theme-accent-1)]"></div>
                          <span className="opacity-80">图片缓存</span>
                        </div>
                        <span className="font-medium">6.2 MB</span>
                      </div>
                      <div className="flex items-center justify-between text-[13px]">
                        <div className="flex items-center gap-2">
                          <div className="w-2 h-2 rounded-full bg-purple-500"></div>
                          <span className="opacity-80">应用配置</span>
                        </div>
                        <span className="font-medium">3.3 MB</span>
                      </div>
                    </div>
                  </div>
                  
                  <div className="flex gap-3">
                     <button className="flex-1 bg-black/5 dark:bg-white/5 hover:bg-black/10 dark:hover:bg-white/10 transition-colors py-3 rounded-2xl text-[14px] font-medium">导出数据</button>
                     <button className="flex-1 text-red-500 bg-red-500/10 hover:bg-red-500/20 transition-colors py-3 rounded-2xl text-[14px] font-medium">清空所有缓存</button>
                  </div>
                </div>
              )}

              {subView === 'main' && activeTab === 'about' && (
                <div className="flex flex-col items-center justify-center py-10 animate-in fade-in zoom-in-95 duration-500">
                   <div className="w-24 h-24 rounded-[32px] border pb-1.5 border-[var(--theme-accent-1)]/30 flex items-center justify-center mb-6 shadow-2xl shadow-[var(--theme-accent-1)]/20 bg-gradient-to-br from-white to-gray-50 dark:from-[#1a1c1e] dark:to-[#121415]">
                     <div className="w-16 h-16 rounded-full bg-gradient-to-tr from-[var(--theme-accent-1)] to-[var(--theme-accent-2)]"></div>
                   </div>
                   
                   <h1 className="text-3xl font-light tracking-widest uppercase mb-2">Weaview</h1>
                   <p className="text-[13px] opacity-50 tracking-wider mb-8">v1.2.0 (Build 20260501)</p>
                   
                   <div className="w-full max-w-[280px] space-y-2">
                     <button className="w-full bg-white dark:bg-white/5 border border-black/5 dark:border-white/5 py-3 rounded-2xl text-[14px] hover:bg-black/[0.02] dark:hover:bg-white/[0.02] transition-colors">检查更新</button>
                     <button className="w-full bg-white dark:bg-white/5 border border-black/5 dark:border-white/5 py-3 rounded-2xl text-[14px] hover:bg-black/[0.02] dark:hover:bg-white/[0.02] transition-colors">开源许可</button>
                     <button className="w-full bg-white dark:bg-white/5 border border-black/5 dark:border-white/5 py-3 rounded-2xl text-[14px] hover:bg-black/[0.02] dark:hover:bg-white/[0.02] transition-colors text-[var(--theme-accent-1)]">报告问题 / 提供反馈</button>
                   </div>
                   
                   <p className="mt-12 text-[11px] opacity-30 text-center">
                     Crafted with intentionality.<br/>
                     © 2026 Weaview App.
                   </p>
                </div>
              )}

              {/* System Prompt View */}
              {subView === 'system_prompt' && (
                <div className="flex flex-col h-full animate-in fade-in slide-in-from-right-4 duration-500">
                  <div className="flex-1 flex flex-col pt-2 h-[300px]">
                    <p className="text-[13px] opacity-50 mb-4 ml-1">修改此提示词将改变AI在此环境中的表现形态与语言风格。如果您想恢复，请清空内容。</p>
                    <textarea 
                      value={systemPrompt}
                      onChange={(e) => setSystemPrompt?.(e.target.value)}
                      placeholder="在此输入全局系统提示词..."
                      className="flex-1 w-full bg-black/5 dark:bg-white/5 rounded-[24px] p-5 text-[14px] leading-loose resize-none outline-none border border-transparent focus:border-[var(--theme-accent-1)]/50 transition-colors shadow-inner"
                    />
                  </div>
                </div>
              )}

              {/* Memory Management View */}
              {subView === 'memory_management' && (
                <div className="flex flex-col h-full animate-in fade-in slide-in-from-right-4 duration-500">
                  <p className="text-[13px] opacity-50 mb-6 text-center pt-2">AI将会记住关于您的重要信息，以便提供更个性化的回应。</p>
                  
                  <div className="mb-6 flex gap-2">
                    <input 
                      type="text" 
                      value={newMemory}
                      onChange={(e) => setNewMemory(e.target.value)}
                      placeholder="手动添加记忆..."
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') handleAddMemory();
                      }}
                      className="flex-1 bg-black/5 dark:bg-white/5 rounded-2xl px-4 py-3 text-[14px] outline-none border border-transparent focus:border-[var(--theme-accent-1)]/50 transition-colors"
                    />
                    <button 
                      onClick={handleAddMemory}
                      disabled={!newMemory.trim()}
                      className="w-12 shrink-0 bg-[var(--theme-accent-1)] text-white rounded-2xl flex items-center justify-center disabled:opacity-50 transition-opacity"
                    >
                      <Plus className="w-5 h-5" />
                    </button>
                  </div>

                  <div className="space-y-3">
                     {memories.length === 0 ? (
                        <div className="text-center py-10 opacity-40 text-[13px]">
                          暂无记忆
                        </div>
                     ) : (
                       memories.map((memory, i) => (
                         <div key={i} className="bg-black/5 dark:bg-white/5 rounded-[20px] p-4 flex items-start justify-between group">
                            <div className="text-[14px] leading-relaxed pr-4">{memory}</div>
                            <button 
                              onClick={() => handleDeleteMemory(i)}
                              className="p-1.5 rounded-full hover:bg-red-500/10 text-red-500/60 hover:text-red-500 transition-colors shrink-0"
                            >
                               <Trash2 className="w-4 h-4" />
                            </button>
                         </div>
                       ))
                     )}
                  </div>

                  <div className="mt-8 bg-white dark:bg-white/5 rounded-[24px] overflow-hidden border border-black/5 dark:border-white/5">
                    <div 
                      onClick={() => setGlobalMemoryEnabled?.(!globalMemoryEnabled)}
                      className="p-4 px-5 border-b border-black/5 dark:border-white/5 cursor-pointer hover:bg-black/[0.02] dark:hover:bg-white/[0.02] transition-colors flex items-center justify-between group"
                    >
                      <div className="flex flex-col">
                        <span className="text-[15px] font-medium">全局记忆</span>
                        <span className="text-[12px] opacity-50">将记录的记忆应用于所有对话</span>
                      </div>
                      <div className={`w-12 h-6 rounded-full relative p-0.5 transition-colors ${globalMemoryEnabled ? 'bg-[#10B981]' : 'bg-black/10 dark:bg-white/10'}`}>
                        <div className={`w-5 h-5 rounded-full bg-white shadow-sm transition-transform ${globalMemoryEnabled ? 'ml-auto' : 'mr-auto'}`}></div>
                      </div>
                    </div>
                    
                    <div 
                      onClick={() => setReferenceHistoryEnabled?.(!referenceHistoryEnabled)}
                      className="p-4 px-5 cursor-pointer hover:bg-black/[0.02] dark:hover:bg-white/[0.02] transition-colors flex items-center justify-between group"
                    >
                      <div className="flex flex-col">
                        <span className="text-[15px] font-medium">参考历史记忆</span>
                        <span className="text-[12px] opacity-50">将最近的历史聊天用于当前上下文</span>
                      </div>
                      <div className={`w-12 h-6 rounded-full relative p-0.5 transition-colors ${referenceHistoryEnabled ? 'bg-[#10B981]' : 'bg-black/10 dark:bg-white/10'}`}>
                        <div className={`w-5 h-5 rounded-full bg-white shadow-sm transition-transform ${referenceHistoryEnabled ? 'ml-auto' : 'mr-auto'}`}></div>
                      </div>
                    </div>
                  </div>

                  {memories.length > 0 && (
                    <button 
                      onClick={handleClearMemories}
                      className="mt-6 text-[14px] font-medium text-red-500 bg-red-500/10 hover:bg-red-500/20 transition-colors py-3 rounded-2xl w-full"
                    >
                      清空所有记忆
                    </button>
                  )}
                </div>
              )}

              {/* Model Role Config View */}
              {subView === 'model_role_config' && editingRole && (
                <div className="flex flex-col h-[calc(100%-44px)] animate-in fade-in slide-in-from-right-4 duration-500">
                  <div className="space-y-6 overflow-y-auto no-scrollbar pb-24 mt-2">
                    <section>
                      <h3 className="text-[12px] font-bold tracking-widest uppercase opacity-40 px-1 mb-3">默认模型</h3>
                      <div className="bg-white dark:bg-white/5 rounded-[24px] border border-black/5 dark:border-white/5 p-4 space-y-4">
                        <div className="relative">
                          <label className="text-[14px] opacity-60 ml-1 mb-1 block">提供商</label>
                          <button
                            onClick={() => setIsRoleProviderDropdownOpen(!isRoleProviderDropdownOpen)}
                            className="w-full bg-black/5 dark:bg-white/5 border border-transparent hover:border-black/5 dark:hover:border-white/5 text-[15px] px-4 py-3.5 rounded-2xl outline-none text-left flex items-center justify-between transition-colors shadow-sm"
                          >
                            <span className="truncate">{roleDraft.provider || '未选择'}</span>
                            <ChevronRight className={`w-4 h-4 opacity-40 transition-transform ${isRoleProviderDropdownOpen ? '-rotate-90' : 'rotate-90'}`} />
                          </button>
                          {isRoleProviderDropdownOpen && (
                            <div className="absolute top-full left-0 right-0 mt-2 z-50">
                               <div className="fixed inset-0 z-40" onClick={() => setIsRoleProviderDropdownOpen(false)} />
                               <div className="absolute top-0 left-0 right-0 bg-white dark:bg-[#2a2d30] border border-black/5 dark:border-white/5 rounded-2xl shadow-xl z-50 max-h-[250px] overflow-y-auto no-scrollbar py-1">
                                 <div
                                   onClick={() => { setRoleDraft(prev => ({ ...prev, provider: '', model: '' })); setIsRoleProviderDropdownOpen(false); }}
                                   className={`px-4 py-3 text-[15px] cursor-pointer transition-colors hover:bg-black/5 dark:hover:bg-white/5 ${!roleDraft.provider ? 'bg-[var(--theme-accent-1)]/10 text-[var(--theme-accent-1)] font-medium' : ''}`}
                                 >
                                   未选择
                                 </div>
                                 {providers.map(p => (
                                   <div
                                     key={p.name}
                                     onClick={() => { setRoleDraft(prev => ({ ...prev, provider: p.name, model: '' })); setIsRoleProviderDropdownOpen(false); }}
                                     className={`px-4 py-3 text-[15px] cursor-pointer transition-colors hover:bg-black/5 dark:hover:bg-white/5 ${roleDraft.provider === p.name ? 'bg-[var(--theme-accent-1)]/10 text-[var(--theme-accent-1)] font-medium' : ''}`}
                                   >
                                     <span className="truncate block">{p.name}</span>
                                   </div>
                                 ))}
                               </div>
                            </div>
                          )}
                        </div>
                        
                        <div className={`relative ${!roleDraft.provider ? 'opacity-50' : ''}`}>
                          <label className="text-[14px] opacity-60 ml-1 mb-1 block">模型</label>
                          <button
                            onClick={() => roleDraft.provider && setIsRoleModelDropdownOpen(!isRoleModelDropdownOpen)}
                            disabled={!roleDraft.provider}
                            className="w-full bg-black/5 dark:bg-white/5 border border-transparent hover:border-black/5 dark:hover:border-white/5 disabled:hover:border-transparent text-[15px] px-4 py-3.5 rounded-2xl outline-none text-left flex items-center justify-between transition-colors shadow-sm disabled:cursor-not-allowed"
                          >
                            <span className="truncate">{roleDraft.model || '未选择'}</span>
                            <ChevronRight className={`w-4 h-4 opacity-40 transition-transform ${isRoleModelDropdownOpen ? '-rotate-90' : 'rotate-90'}`} />
                          </button>
                          {isRoleModelDropdownOpen && roleDraft.provider && (
                            <div className="absolute top-full left-0 right-0 mt-2 z-50">
                               <div className="fixed inset-0 z-40" onClick={() => setIsRoleModelDropdownOpen(false)} />
                               <div className="absolute top-0 left-0 right-0 bg-white dark:bg-[#2a2d30] border border-black/5 dark:border-white/5 rounded-2xl shadow-xl z-50 max-h-[250px] overflow-y-auto no-scrollbar py-1">
                                 <div
                                   onClick={() => { setRoleDraft(prev => ({ ...prev, model: '' })); setIsRoleModelDropdownOpen(false); }}
                                   className={`px-4 py-3 text-[15px] cursor-pointer transition-colors hover:bg-black/5 dark:hover:bg-white/5 ${!roleDraft.model ? 'bg-[var(--theme-accent-1)]/10 text-[var(--theme-accent-1)] font-medium' : ''}`}
                                 >
                                   未选择
                                 </div>
                                 {(providers.find(p => p.name === roleDraft.provider)?.models || []).map(m => (
                                   <div
                                     key={m.id}
                                     onClick={() => { setRoleDraft(prev => ({ ...prev, model: m.name })); setIsRoleModelDropdownOpen(false); }}
                                     className={`px-4 py-3 text-[15px] cursor-pointer transition-colors hover:bg-black/5 dark:hover:bg-white/5 ${roleDraft.model === m.name ? 'bg-[var(--theme-accent-1)]/10 text-[var(--theme-accent-1)] font-medium' : ''}`}
                                   >
                                     <span className="truncate block">{m.name}</span>
                                   </div>
                                 ))}
                               </div>
                            </div>
                          )}
                        </div>
                      </div>
                    </section>
                    
                    <section>
                       <h3 className="text-[12px] font-bold tracking-widest uppercase opacity-40 px-1 mb-3">系统提示词 (System Prompt)</h3>
                       <div className="bg-white dark:bg-white/5 rounded-[24px] border border-black/5 dark:border-white/5 p-2 focus-within:border-[var(--theme-accent-1)] transition-colors shadow-sm">
                         <textarea
                           value={roleDraft.prompt}
                           onChange={(e) => setRoleDraft(prev => ({ ...prev, prompt: e.target.value }))}
                           placeholder="输入自定义提示词..."
                           className="w-full h-[150px] bg-transparent resize-none p-3 text-[14px] leading-relaxed outline-none no-scrollbar placeholder:opacity-30"
                         />
                         <div className="flex justify-between items-center px-4 py-2 border-t border-black/5 dark:border-white/5 mx-1">
                           <span className="text-[11px] opacity-40">{roleDraft.prompt.length} 字符</span>
                           <button 
                             onClick={() => setRoleDraft(prev => ({ ...prev, prompt: DEFAULT_ROLES[editingRole as keyof typeof DEFAULT_ROLES].defaultPrompt }))}
                             className="text-[11px] font-medium text-[var(--theme-accent-1)] hover:opacity-80 transition-opacity"
                           >
                             恢复默认
                           </button>
                         </div>
                       </div>
                       <p className="text-[12px] opacity-50 mt-3 px-2 leading-relaxed">
                         {DEFAULT_ROLES[editingRole as keyof typeof DEFAULT_ROLES].desc}，此提示词将作为系统角色的基础指令。
                       </p>
                    </section>
                  </div>
                  
                  <div className="absolute bottom-6 left-6 right-6 z-10 flex gap-3">
                     <button
                       onClick={() => {
                         const next = { ...modelAssignments, [editingRole]: roleDraft };
                         setModelAssignments(next);
                         localStorage.setItem('ai_model_assignments', JSON.stringify(next));
                         setSubView('main');
                         setEditingRole(null);
                       }}
                       className="flex-1 bg-[var(--theme-accent-1)] text-white text-[15px] font-medium py-4 rounded-[20px] transition-all hover:opacity-90 active:scale-[0.98] shadow-lg shadow-[var(--theme-accent-1)]/20"
                     >
                       保存设置
                     </button>
                  </div>
                </div>
              )}

              {/* Search Engine Config View */}
              {subView === 'search_engine_config' && (
                <div className="flex flex-col h-full animate-in fade-in slide-in-from-right-4 duration-500">
                  <div className="flex-1 flex flex-col pt-2 h-[300px] overflow-y-auto no-scrollbar pb-24">
                    <p className="text-[13px] opacity-50 mb-6 px-1">配置默认的搜索引擎与对应的API Key。您可以自行注册并获取各个厂商的密钥。</p>
                    
                    <div className="space-y-4">
                      {SEARCH_ENGINES.map(engine => (
                        <div key={engine.id} className={`bg-white dark:bg-white/5 rounded-[20px] p-4 border transition-all ${searchConfig.active === engine.id ? 'border-[var(--theme-accent-1)] shadow-sm' : 'border-black/5 dark:border-white/5'}`}>
                           <div 
                             className="flex items-center justify-between cursor-pointer"
                             onClick={() => {
                               const next = { ...searchConfig, active: engine.id };
                               setSearchConfig(next);
                               localStorage.setItem('ai_search_config', JSON.stringify(next));
                             }}
                           >
                             <div className="flex items-center gap-3">
                               <div className={`w-5 h-5 rounded-full border-2 flex items-center justify-center transition-colors ${searchConfig.active === engine.id ? 'border-[var(--theme-accent-1)]' : 'border-black/20 dark:border-white/20'}`}>
                                 {searchConfig.active === engine.id && <div className="w-2.5 h-2.5 rounded-full bg-[var(--theme-accent-1)]" />}
                               </div>
                               <span className="text-[15px] font-medium">{engine.name}</span>
                             </div>
                           </div>
                           
                           {searchConfig.active === engine.id && (
                             <div className="mt-4 pt-4 border-t border-black/5 dark:border-white/5 animate-in fade-in duration-300">
                               <label className="text-[13px] opacity-60 ml-1 mb-1 block">API Key</label>
                               <input 
                                  type="password"
                                  value={searchConfig.keys[engine.id] || ''}
                                  onChange={(e) => {
                                    const next = { 
                                      ...searchConfig, 
                                      keys: { ...searchConfig.keys, [engine.id]: e.target.value } 
                                    };
                                    setSearchConfig(next);
                                    localStorage.setItem('ai_search_config', JSON.stringify(next));
                                  }}
                                  placeholder={`输入 ${engine.name} 的 API Key`}
                                  className="w-full bg-black/5 dark:bg-white/5 border border-transparent focus:border-black/10 dark:focus:border-white/10 text-[14px] px-4 py-3 rounded-2xl outline-none transition-colors"
                               />
                               <div className="mt-2 text-[12px] opacity-40 px-1">
                                 {engine.id === 'tavily' && 'Tavily 提供专为 AI 打造的快速搜索服务。'}
                                 {engine.id === 'brave' && 'Brave Search 提供完整的独立索引。'}
                                 {engine.id === 'perplexity' && 'Perplexity 提供强大的智能问答引擎。'}
                               </div>
                             </div>
                           )}
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              )}

              {/* TTS Config View */}
              {subView === 'tts_config' && editingTtsId && (
                <div className="flex flex-col h-full animate-in fade-in slide-in-from-right-4 duration-500">
                  <div className="flex-1 flex flex-col pt-2 h-[300px] overflow-y-auto no-scrollbar pb-32">
                    
                    <div className="space-y-4 px-1">
                      <div className="space-y-2">
                        <label className="text-[14px] font-medium opacity-60 ml-1 block">提供商类型</label>
                        <select
                          value={ttsDraft.type}
                          onChange={(e) => setTtsDraft(prev => ({ ...prev, type: e.target.value }))}
                          className="w-full bg-black/5 dark:bg-white/5 border border-transparent focus:border-[var(--theme-accent-1)]/50 text-[15px] px-4 py-3.5 rounded-2xl outline-none"
                        >
                          <option value="xiaomi">Xiaomi MiMo TTS</option>
                          <option value="openai">OpenAI TTS</option>
                          <option value="azure">Azure TTS</option>
                          <option value="edge">Edge TTS</option>
                          <option value="custom">自定义 (Custom)</option>
                        </select>
                      </div>

                      <div className="space-y-2">
                        <label className="text-[14px] font-medium opacity-60 ml-1 block">显示名称</label>
                        <input
                          type="text"
                          value={ttsDraft.name}
                          onChange={(e) => setTtsDraft(prev => ({ ...prev, name: e.target.value }))}
                          placeholder="例如：OpenAI 语音"
                          className="w-full bg-black/5 dark:bg-white/5 border border-transparent focus:border-[var(--theme-accent-1)]/50 text-[15px] px-4 py-3.5 rounded-2xl outline-none"
                        />
                      </div>

                      {ttsDraft.type !== 'edge' && (
                        <div className="space-y-2">
                          <label className="text-[14px] font-medium opacity-60 ml-1 block">API Key</label>
                          <input
                            type="password"
                            value={ttsDraft.apiKey}
                            onChange={(e) => setTtsDraft(prev => ({ ...prev, apiKey: e.target.value }))}
                            placeholder="Bearer Token 或 API 密钥"
                            className="w-full bg-black/5 dark:bg-white/5 border border-transparent focus:border-[var(--theme-accent-1)]/50 text-[15px] px-4 py-3.5 rounded-2xl outline-none"
                          />
                        </div>
                      )}

                      <div className="space-y-2">
                        <label className="text-[14px] font-medium opacity-60 ml-1 block">Base URL</label>
                        <input
                          type="text"
                          value={ttsDraft.baseUrl}
                          onChange={(e) => setTtsDraft(prev => ({ ...prev, baseUrl: e.target.value }))}
                          placeholder="https://api.openai.com/v1"
                          className="w-full bg-black/5 dark:bg-white/5 border border-transparent focus:border-[var(--theme-accent-1)]/50 text-[15px] px-4 py-3.5 rounded-2xl outline-none"
                        />
                      </div>

                      <div className="space-y-2">
                        <label className="text-[14px] font-medium opacity-60 ml-1 block">模型名称 (Model)</label>
                        <input
                          type="text"
                          value={ttsDraft.model}
                          onChange={(e) => setTtsDraft(prev => ({ ...prev, model: e.target.value }))}
                          placeholder="例如: tts-1, tts-1-hd"
                          className="w-full bg-black/5 dark:bg-white/5 border border-transparent focus:border-[var(--theme-accent-1)]/50 text-[15px] px-4 py-3.5 rounded-2xl outline-none"
                        />
                      </div>

                      <div className="space-y-2">
                        <label className="text-[14px] font-medium opacity-60 ml-1 block">合成语音 (Voice)</label>
                        <input
                          type="text"
                          value={ttsDraft.voice}
                          onChange={(e) => setTtsDraft(prev => ({ ...prev, voice: e.target.value }))}
                          placeholder="例如: alloy, echo, fable"
                          className="w-full bg-black/5 dark:bg-white/5 border border-transparent focus:border-[var(--theme-accent-1)]/50 text-[15px] px-4 py-3.5 rounded-2xl outline-none"
                        />
                      </div>
                      
                      {ttsDraft.id !== 'xiaomi' && (
                        <div className="pt-4 px-2">
                           <button 
                             onClick={() => {
                               const next = ttsProvidersConfig.filter(t => t.id !== ttsDraft.id);
                               setTtsProvidersConfig(next);
                               localStorage.setItem('ai_tts_providers', JSON.stringify(next));
                               if (activeTtsId === ttsDraft.id) setActiveTtsId('system');
                               setSubView('main');
                             }}
                             className="text-red-500 text-[14px] font-medium hover:underline flex items-center gap-1.5"
                           >
                             <Trash2 className="w-4 h-4"/> 删除此提供商
                           </button>
                        </div>
                      )}
                    </div>
                  </div>
                  
                  <div className="absolute bottom-6 left-6 right-6 z-10 flex gap-3">
                     <button
                       onClick={() => {
                         const existingIndex = ttsProvidersConfig.findIndex(t => t.id === ttsDraft.id);
                         let nextConfig = [...ttsProvidersConfig];
                         if (existingIndex >= 0) {
                           nextConfig[existingIndex] = ttsDraft;
                         } else {
                           nextConfig.push(ttsDraft);
                         }
                         setTtsProvidersConfig(nextConfig);
                         localStorage.setItem('ai_tts_providers', JSON.stringify(nextConfig));
                         setSubView('main');
                         setEditingTtsId(null);
                       }}
                       className="flex-1 bg-[var(--theme-accent-1)] text-white text-[15px] font-medium py-4 rounded-[20px] transition-all hover:opacity-90 active:scale-[0.98] shadow-lg shadow-[var(--theme-accent-1)]/20"
                     >
                       保存设置
                     </button>
                  </div>
                </div>
              )}

              {/* Provider Config View */}
              {subView === 'provider_config' && (
                <div className="flex flex-col h-full animate-in fade-in slide-in-from-right-4 duration-500">
                  <div className="mb-6">
                    <div className="w-16 h-16 rounded-3xl bg-black/5 dark:bg-white/5 flex items-center justify-center mb-4 mx-auto">
                      <Cloud className="w-8 h-8 opacity-60" />
                    </div>
                    <h3 className="text-xl font-medium text-center">
                      {selectedProvider || (
                        <input 
                          type="text" 
                          value={customProviderName}
                          onChange={(e) => setCustomProviderName(e.target.value)}
                          placeholder="自定义提供商名称" 
                          className="bg-transparent text-center outline-none border-b border-black/10 dark:border-white/10 w-[200px] placeholder:text-[15px]"
                          autoFocus
                        />
                      )}
                    </h3>
                    <p className="text-[13px] opacity-50 text-center mt-1">配置此提供商的API凭据以启用相关模型</p>
                  </div>

                  <div className="flex-1 overflow-y-auto w-full no-scrollbar pb-6">
                    {providerTab === 'config' ? (
                      <div className="space-y-4">
                        <div className="space-y-2">
                           <label className="text-[13px] font-medium opacity-60 px-1">API Key</label>
                           <input 
                             type="password" 
                             value={providerApiKey}
                             onChange={(e) => setProviderApiKey(e.target.value)}
                             placeholder={`请输入 ${selectedProvider || 'Provider'} API Key...`}
                             className="w-full bg-black/5 dark:bg-white/5 rounded-2xl px-4 py-3.5 text-[14px] outline-none border border-transparent focus:border-[var(--theme-accent-1)]/50 transition-colors"
                           />
                           <p className="text-[11px] opacity-40 px-1 mt-1">
                             您的API Key仅在本地浏览器中存储，不会被发送至任何第三方服务器。
                           </p>
                        </div>
                        
                        <div className="space-y-2">
                           <label className="text-[13px] font-medium opacity-60 px-1">Base URL (可选)</label>
                           <input 
                             type="text" 
                             value={providerBaseUrl}
                             onChange={(e) => setProviderBaseUrl(e.target.value)}
                             placeholder="https://api.example.com/v1"
                             className="w-full bg-black/5 dark:bg-white/5 rounded-2xl px-4 py-3.5 text-[14px] outline-none border border-transparent focus:border-[var(--theme-accent-1)]/50 transition-colors"
                           />
                           <p className="text-[11px] opacity-40 px-1 mt-1">
                             如果您使用了代理或者中转服务，请在此输入自定义的Base URL。
                           </p>
                        </div>
                      </div>
                    ) : (
                      <div className="space-y-3">
                        {providerModels.length > 0 ? (
                          providerModels.map((model, i) => (
                            <div key={i} className="flex flex-col bg-white dark:bg-white/5 border border-black/5 dark:border-white/5 rounded-[20px] overflow-hidden">
                              <div className="flex items-center justify-between p-4">
                                <div className="flex items-center gap-3 min-w-0 flex-1 pr-2">
                                  <Cpu className="w-5 h-5 opacity-60 shrink-0" />
                                  <div className="flex flex-col min-w-0 flex-1">
                                    <span className="text-[14px] font-medium truncate block w-full" title={model.name}>{model.name}</span>
                                    <div className="flex gap-1.5 mt-1 opacity-60">
                                      {model.capabilities.includes('chat') && <MessageSquare className="w-3.5 h-3.5" />}
                                      {model.capabilities.includes('vision') && <Eye className="w-3.5 h-3.5" />}
                                      {model.capabilities.includes('image') && <ImageIcon className="w-3.5 h-3.5" />}
                                      {model.capabilities.includes('tool') && <Wrench className="w-3.5 h-3.5" />}
                                      {model.capabilities.includes('reason') && <Brain className="w-3.5 h-3.5" />}
                                    </div>
                                  </div>
                                </div>
                                <div className="flex items-center gap-1">
                                  <button onClick={() => setEditingModel(model)} className="p-2 hover:bg-black/5 dark:hover:bg-white/5 rounded-full transition-colors opacity-60 hover:opacity-100">
                                    <Edit2 className="w-4 h-4" />
                                  </button>
                                  <button onClick={() => updateProviderModelsAndSync(providerModels.filter((_, idx) => idx !== i))} className="p-2 hover:bg-black/5 dark:hover:bg-white/5 rounded-full transition-colors text-red-500 opacity-60 hover:opacity-100">
                                    <X className="w-4 h-4" />
                                  </button>
                                </div>
                              </div>
                            </div>
                          ))
                        ) : (
                          <div className="text-center py-8 text-[13px] opacity-40">
                            暂无可用模型，请拉取或手动添加
                          </div>
                        )}
                        
                        <button 
                          onClick={() => {
                            const customModelName = window.prompt("请输入模型名称:(例如: gpt-4-turbo)");
                            if (customModelName) {
                              updateProviderModelsAndSync([...providerModels, { id: customModelName, name: customModelName, capabilities: [] }]);
                            }
                          }}
                          className="w-full py-4 rounded-[20px] border border-dashed border-black/20 dark:border-white/20 text-black/50 dark:text-white/50 hover:bg-black/5 dark:hover:bg-white/5 transition-colors flex items-center justify-center gap-2 text-[14px] font-medium"
                        >
                          <Plus className="w-4 h-4" />
                          添加新模型
                        </button>
                      </div>
                    )}
                  </div>

                  <div className="mt-auto pt-4 border-t border-black/5 dark:border-white/5 flex flex-col gap-3">
                     {providerTab === 'models' && (
                       <div className="flex flex-col gap-1 w-full">
                         <div className="flex gap-3 mb-1">
                           <button 
                             onClick={() => {
                             if (!providerApiKey) {
                               setPullStatus('error');
                               setPullMessage('需要 API Key 才能拉取');
                               return;
                             }
                             setPullStatus('loading');
                             setPullMessage('正在拉取...');
                            let baseUrl = (providerBaseUrl || 'https://api.openai.com/v1').trim().replace(/\/$/, '');
                             if (!baseUrl.startsWith('http')) baseUrl = 'https://' + baseUrl;

                             fetch(`${baseUrl}/models`, {
                               method: 'GET',
                               headers: {
                                 'Authorization': `Bearer ${providerApiKey?.trim()}`,
                                 'Accept': 'application/json'
                               }
                             })
                             .then(async res => {
                               if (!res.ok) {
                                 let text = await res.text().catch(() => '');
                                 throw new Error(`HTTP ${res.status}: ${text.slice(0, 100)}`);
                               }
                               return res.json();
                             })
                             .then(data => {
                               setPullStatus('idle');
                               let records = [];
                               if (Array.isArray(data)) records = data;
                               else if (data && Array.isArray(data.data)) records = data.data;
                               else if (data && Array.isArray(data.models)) records = data.models;

                               if (records.length > 0) {
                                 const models = records.map((m: any) => {
                                   const idLower = String(m.id || m.name || '').toLowerCase();
                                   const caps = [];
                                   if (idLower.includes('vision') || idLower.includes('vl') || idLower.includes('omni')) caps.push('vision');
                                   if (idLower.includes('reason') || idLower.includes('think')) caps.push('reason');
                                   if (idLower.includes('tool') || idLower.includes('function')) caps.push('tool');
                                   if (idLower.includes('image')) caps.push('image');
                                   if (caps.length === 0) caps.push('chat');
                                   return {
                                     id: m.id || m.name || String(m), 
                                     name: m.name || m.id || String(m),
                                     capabilities: caps
                                   };
                                 });
                                 setFetchedModels(models);
                                 setSelectedModelsToPull([]);
                                 setShowPullModal(true);
                               } else {
                                 setPullStatus('error');
                                 setPullMessage('拉取失败，未找到模型列表数据');
                               }
                             })
                             .catch(err => {
                               setPullStatus('error');
                               setPullMessage(`拉取失败: ${err.message === 'Failed to fetch' ? '网络错误(CORS或地址无效)' : err.message}`);
                             });
                           }}
                           className="flex-1 flex items-center justify-center bg-black/5 dark:bg-white/5 font-medium py-3 rounded-2xl transition-all hover:bg-black/10 dark:hover:bg-white/10 active:scale-[0.98]"
                         >
                           <span className="text-[14px]">拉取模型列表</span>
                         </button>
                         <button 
                           onClick={() => {
                             if (!providerApiKey) {
                               setTestStatus('error');
                               setTestMessage('需要 API Key 才能进行测试');
                               return;
                             }
                             if (providerModels.length === 0) {
                               setTestStatus('error');
                               setTestMessage('请先添加至少一个模型');
                               return;
                             }
                             setShowTestModal(true);
                             setTestModelId(providerModels[0].id);
                             setTestStatus('idle');
                             setTestMessage('');
                           }}
                           className="flex-1 flex items-center justify-center bg-black/5 dark:bg-white/5 font-medium py-3 rounded-2xl transition-all hover:bg-black/10 dark:hover:bg-white/10 active:scale-[0.98]"
                         >
                           <span className="text-[14px]">连通性测试</span>
                         </button>
                       </div>
                       {(pullStatus !== 'idle' || testStatus !== 'idle') && (
                         <div className="text-center px-4 mb-2">
                            {pullStatus !== 'idle' && (
                              <div className={`text-[12px] leading-tight break-words ${pullStatus === 'error' ? 'text-red-500' : pullStatus === 'success' ? 'text-green-500' : 'opacity-60 text-[var(--theme-accent-1)]'}`}>
                                {pullStatus === 'loading' ? '正在拉取...' : pullMessage}
                              </div>
                            )}
                            {testStatus !== 'idle' && (
                              <div className={`text-[12px] leading-tight break-words mt-1 ${testStatus === 'error' ? 'text-red-500' : testStatus === 'success' ? 'text-green-500' : 'opacity-60 text-[var(--theme-accent-1)]'}`}>
                                {testStatus === 'loading' ? '正在连接...' : testMessage}
                              </div>
                            )}
                         </div>
                       )}
                     </div>
                     )}

                     {providerTab === 'config' && (
                       <div className="flex gap-2 mb-1">
                         <button 
                           onClick={handleSaveProviderConfig}
                           className="flex-1 bg-[var(--theme-accent-1)] text-white text-[14px] font-medium py-3 rounded-2xl transition-all hover:opacity-90 active:scale-[0.98] shadow-lg shadow-[var(--theme-accent-1)]/20"
                         >
                           保存配置
                         </button>
                         <button 
                           onClick={handleEnableProvider}
                           disabled={!providerApiKey}
                           className="flex-1 bg-black/5 dark:bg-white/5 text-[14px] font-medium py-3 rounded-2xl transition-all hover:bg-black/10 dark:hover:bg-white/10 active:scale-[0.98] disabled:opacity-30 disabled:cursor-not-allowed"
                         >
                           启用
                         </button>
                       </div>
                     )}


                     <div className="flex gap-2 p-1 bg-black/5 dark:bg-white/5 rounded-full">
                       <button 
                         onClick={() => setProviderTab('config')} 
                         className={`flex-1 py-2.5 rounded-full text-[13px] font-medium transition-all ${providerTab === 'config' ? 'bg-white text-black dark:bg-[#1a1c1e] dark:text-white shadow-sm' : 'opacity-60 hover:opacity-100'}`}
                       >
                         配置
                       </button>
                       <button 
                         onClick={() => setProviderTab('models')} 
                         className={`flex-1 py-2.5 rounded-full text-[13px] font-medium transition-all ${providerTab === 'models' ? 'bg-white text-black dark:bg-[#1a1c1e] dark:text-white shadow-sm' : 'opacity-60 hover:opacity-100'}`}
                       >
                         模型
                       </button>
                     </div>
                  </div>

                  {showPullModal && (
                    <div className="absolute inset-0 z-50 bg-[#F3F4F6] dark:bg-[#1a1c1e] flex flex-col animate-in fade-in slide-in-from-bottom-4 duration-300 rounded-[32px]">
                       <div className="flex items-center justify-between p-6 pb-4">
                         <div className="flex gap-2">
                           <button onClick={() => setShowPullModal(false)} className="p-2 -ml-2 rounded-full hover:bg-black/5 dark:hover:bg-white/5 transition-colors">
                             <ChevronRight className="w-5 h-5 opacity-60 rotate-180" />
                           </button>
                           <h2 className="text-[17px] font-medium tracking-wide">模型列表</h2>
                         </div>
                         <button 
                           onClick={() => {
                             const toAdd = fetchedModels.filter(m => selectedModelsToPull.includes(m.id)).map(m => ({ id: m.id, name: m.name, capabilities: m.capabilities }));
                             updateProviderModelsAndSync([...providerModels, ...toAdd]);
                             setShowPullModal(false);
                           }}
                           className="text-[14px] font-medium text-[var(--theme-accent-1)] opacity-80 hover:opacity-100 transition-colors"
                         >
                           确认添加
                         </button>
                       </div>
                       <div className="px-6 pb-4">
                         <div className="flex items-center bg-black/5 dark:bg-white/5 rounded-2xl px-4 py-2 text-[14px]">
                           <input 
                             type="text" 
                             value={modelSearchQuery}
                             onChange={(e) => setModelSearchQuery(e.target.value)}
                             placeholder="搜索模型名称或ID..."
                             className="w-full bg-transparent outline-none border-transparent focus:ring-0 placeholder:text-black/30 dark:placeholder:text-white/30"
                           />
                           {modelSearchQuery && (
                             <button onClick={() => setModelSearchQuery('')} className="p-1 opacity-40 hover:opacity-100 transition-colors">
                               <X className="w-4 h-4" />
                             </button>
                           )}
                         </div>
                       </div>
                       
                       <div className="flex-1 overflow-y-auto px-6 pb-6 space-y-3">
                         {fetchedModels.filter(m => m.name.toLowerCase().includes(modelSearchQuery.toLowerCase()) || m.id.toLowerCase().includes(modelSearchQuery.toLowerCase())).map(model => (
                           <div 
                             key={model.id}
                             onClick={() => {
                               setSelectedModelsToPull(prev => 
                                 prev.includes(model.id) ? prev.filter(id => id !== model.id) : [...prev, model.id]
                               );
                             }}
                             className={`p-4 rounded-[20px] border flex items-center justify-between cursor-pointer transition-all ${selectedModelsToPull.includes(model.id) ? 'bg-black/5 dark:bg-white/10 border-[var(--theme-accent-1)] shadow-sm' : 'bg-white dark:bg-white/5 border-black/5 dark:border-white/5 hover:border-black/10 dark:hover:border-white/10'}`}
                           >
                             <div className="flex items-center gap-3 min-w-0 flex-1 pr-2">
                               <div className="flex flex-col min-w-0 flex-1">
                                 <span className="text-[15px] font-medium truncate block w-full" title={model.name}>{model.name}</span>
                                 <div className="flex gap-1.5 mt-1.5 opacity-60">
                                   {model.capabilities.includes('chat') && <MessageSquare className="w-3.5 h-3.5" />}
                                   {model.capabilities.includes('vision') && <Eye className="w-3.5 h-3.5" />}
                                   {model.capabilities.includes('image') && <ImageIcon className="w-3.5 h-3.5" />}
                                   {model.capabilities.includes('tool') && <Wrench className="w-3.5 h-3.5" />}
                                   {model.capabilities.includes('reason') && <Brain className="w-3.5 h-3.5" />}
                                 </div>
                               </div>
                             </div>
                             <div className={`w-5 h-5 rounded-full border flex items-center justify-center transition-colors ${selectedModelsToPull.includes(model.id) ? 'bg-[var(--theme-accent-1)] border-[var(--theme-accent-1)]' : 'border-black/20 dark:border-white/20'}`}>
                               {selectedModelsToPull.includes(model.id) && <Check className="w-3 h-3 text-white" strokeWidth={3} />}
                             </div>
                           </div>
                         ))}
                       </div>
                    </div>
                  )}

                  {editingModel && (
                    <div className="absolute inset-0 z-50 bg-[#F3F4F6] dark:bg-[#1a1c1e] flex flex-col animate-in fade-in slide-in-from-bottom-4 duration-300 rounded-[32px]">
                       <div className="flex items-center justify-between p-6 pb-4">
                         <div className="flex gap-2">
                           <button onClick={() => setEditingModel(null)} className="p-2 -ml-2 rounded-full hover:bg-black/5 dark:hover:bg-white/5 transition-colors">
                             <ChevronRight className="w-5 h-5 opacity-60 rotate-180" />
                           </button>
                           <h2 className="text-[17px] font-medium tracking-wide">编辑模型</h2>
                         </div>
                       </div>
                       <div className="flex-1 overflow-y-auto px-6 pb-6 space-y-4">
                         <div className="flex flex-col gap-2">
                           <span className="text-[14px] font-medium opacity-60">模型标识名 (ID)</span>
                           <input 
                              type="text" 
                              value={editingModel.id} 
                              readOnly
                              className="w-full bg-black/5 dark:bg-white/5 text-[15px] px-4 py-3 rounded-2xl outline-none opacity-60"
                           />
                         </div>
                         <div className="flex flex-col gap-2">
                           <span className="text-[14px] font-medium opacity-60">显示名称</span>
                           <input 
                              type="text" 
                              value={editingModel.name}
                              onChange={(e) => setEditingModel({...editingModel, name: e.target.value})}
                              className="w-full bg-black/5 dark:bg-white/5 text-[15px] px-4 py-3 rounded-2xl focus:ring-2 focus:ring-[var(--theme-accent-1)]/30 outline-none transition-all placeholder:text-black/30 dark:placeholder:text-white/30"
                           />
                         </div>
                         <div className="flex flex-col gap-2 mt-4">
                           <span className="text-[14px] font-medium opacity-60">能力配置</span>
                           <div className="space-y-2">
                             {[
                               { id: 'vision', icon: Eye, label: 'Vision (视觉处理)' },
                               { id: 'image', icon: ImageIcon, label: 'Image Output (图像生成)' },
                               { id: 'tool', icon: Wrench, label: 'Tool Calling (函数调用)' },
                               { id: 'reason', icon: Brain, label: 'Reasoning (深度推理)' }
                             ].map(cap => (
                               <label key={cap.id} className="flex items-center justify-between p-4 bg-white dark:bg-white/5 border border-black/5 dark:border-white/5 rounded-2xl cursor-pointer hover:border-black/10 dark:hover:border-white/10 transition-colors">
                                 <div className="flex items-center gap-3">
                                   <cap.icon className="w-5 h-5 opacity-60" />
                                   <span className="text-[14px] font-medium">{cap.label}</span>
                                 </div>
                                 <div className={`w-10 h-6 rounded-full flex items-center px-1 transition-colors ${editingModel.capabilities.includes(cap.id) ? 'bg-[var(--theme-accent-1)]' : 'bg-black/10 dark:bg-white/10'}`}>
                                    <div className={`w-4 h-4 bg-white rounded-full shadow-sm transition-all ${editingModel.capabilities.includes(cap.id) ? 'translate-x-4' : 'translate-x-0'}`}></div>
                                 </div>
                                 <input 
                                   type="checkbox" 
                                   className="hidden" 
                                   checked={editingModel.capabilities.includes(cap.id)}
                                   onChange={(e) => {
                                     setEditingModel(prev => {
                                       if (!prev) return prev;
                                       const caps = e.target.checked 
                                         ? [...prev.capabilities, cap.id] 
                                         : prev.capabilities.filter(c => c !== cap.id);
                                       return { ...prev, capabilities: caps };
                                     });
                                   }}
                                 />
                               </label>
                             ))}
                           </div>
                         </div>
                       </div>
                       <div className="p-6 pt-0 mt-auto bg-[#F3F4F6] dark:bg-[#1a1c1e]">
                         <button 
                           onClick={() => {
                             updateProviderModelsAndSync(providerModels.map(m => m.id === editingModel.id ? editingModel : m));
                             setEditingModel(null);
                           }}
                           className="w-full bg-[var(--theme-accent-1)] text-white text-[15px] font-medium py-3.5 rounded-2xl transition-all hover:opacity-90 active:scale-[0.98] shadow-lg shadow-[var(--theme-accent-1)]/20"
                         >
                           保存配置
                         </button>
                       </div>
                    </div>
                  )}

                  {showTestModal && (
                    <div className="absolute inset-0 z-50 bg-[#F3F4F6] dark:bg-[#1a1c1e] flex flex-col animate-in fade-in slide-in-from-bottom-4 duration-300 rounded-[32px]">
                       <div className="flex items-center justify-between p-6 pb-4">
                         <div className="flex gap-2">
                           <button onClick={() => setShowTestModal(false)} className="p-2 -ml-2 rounded-full hover:bg-black/5 dark:hover:bg-white/5 transition-colors">
                             <ChevronRight className="w-5 h-5 opacity-60 rotate-180" />
                           </button>
                           <h2 className="text-[17px] font-medium tracking-wide">连通性测试</h2>
                         </div>
                       </div>
                       <div className="flex-1 px-6 pb-6 mt-4">
                         <p className="text-[14px] opacity-60 mb-3">选择测试模型</p>
                         <div className="relative">
                            <button
                              onClick={() => setIsTestModelDropdownOpen(!isTestModelDropdownOpen)}
                              className="w-full bg-white dark:bg-white/5 border border-black/5 dark:border-white/5 hover:border-black/10 dark:hover:border-white/10 text-[15px] px-4 py-3.5 rounded-2xl outline-none text-left flex items-center justify-between transition-colors shadow-sm"
                            >
                              <span className="truncate">{providerModels.find(m => m.id === testModelId)?.name || '选择模型...'}</span>
                              <ChevronRight className={`w-4 h-4 opacity-40 transition-transform ${isTestModelDropdownOpen ? '-rotate-90' : 'rotate-90'}`} />
                            </button>
                            
                            {isTestModelDropdownOpen && (
                              <div className="absolute top-full left-0 right-0 mt-2 z-50">
                                <div 
                                  className="fixed inset-0 z-40" 
                                  onClick={() => setIsTestModelDropdownOpen(false)}
                                />
                                <div className="absolute top-0 left-0 right-0 bg-white dark:bg-[#2a2d30] border border-black/5 dark:border-white/5 rounded-2xl shadow-xl z-50 max-h-[250px] overflow-y-auto no-scrollbar py-1">
                                  {providerModels.map(m => (
                                    <div
                                      key={m.id}
                                      onClick={() => {
                                        setTestModelId(m.id);
                                        setIsTestModelDropdownOpen(false);
                                      }}
                                      className={`px-4 py-3 text-[15px] cursor-pointer transition-colors hover:bg-black/5 dark:hover:bg-white/5 ${testModelId === m.id ? 'bg-[var(--theme-accent-1)]/10 text-[var(--theme-accent-1)] font-medium' : ''}`}
                                    >
                                      <span className="truncate block">{m.name}</span>
                                    </div>
                                  ))}
                                </div>
                              </div>
                            )}
                         </div>
                         
                         <div className="mt-8 flex flex-col items-center justify-center">
                           <div className={`w-20 h-20 rounded-full flex items-center justify-center mb-4 transition-colors ${testStatus === 'success' ? 'bg-green-500/10 text-green-500' : testStatus === 'error' ? 'bg-red-500/10 text-red-500' : 'bg-black/5 dark:bg-white/5 text-[var(--theme-accent-1)]'}`}>
                               {testStatus === 'success' ? <Check className="w-8 h-8" /> : testStatus === 'error' ? <X className="w-8 h-8" /> : testStatus === 'loading' ? <Loader2 className="w-8 h-8 animate-spin" /> : <Globe className="w-8 h-8 opacity-40" />}
                           </div>
                           <p className={`text-[15px] max-w-[80%] text-center break-words ${testStatus === 'error' ? 'text-red-500' : testStatus === 'success' ? 'text-green-500' : 'opacity-60'}`}>
                             {testStatus === 'idle' ? '准备就绪' : testMessage}
                           </p>
                         </div>
                       </div>
                       <div className="p-6 pt-0 mt-auto bg-[#F3F4F6] dark:bg-[#1a1c1e]">
                         <button 
                           onClick={() => {
                             if (!providerApiKey) {
                               setTestStatus('error');
                               setTestMessage('需要 API Key 才能进行测试');
                               return;
                             }
                             setTestStatus('loading');
                             setTestMessage('正在测试连接...');
                             
                             let baseUrl = (providerBaseUrl || 'https://api.openai.com/v1').trim().replace(/\/$/, '');
                             if (!baseUrl.startsWith('http')) baseUrl = 'https://' + baseUrl;
                             
                             const start = Date.now();
                             fetch(`${baseUrl}/chat/completions`, {
                               method: 'POST',
                               headers: {
                                 'Authorization': `Bearer ${providerApiKey}`,
                                 'Content-Type': 'application/json'
                               },
                               body: JSON.stringify({
                                 model: testModelId,
                                 messages: [{ role: 'user', content: 'hello' }],
                                 max_tokens: 5
                               })
                             }).then(async res => {
                               if (!res.ok) {
                                  let errText = await res.text();
                                  try {
                                     const errJson = JSON.parse(errText);
                                     if(errJson.error && errJson.error.message) errText = errJson.error.message;
                                  } catch(e){}
                                  throw new Error(`HTTP Error ${res.status}: ${errText}`);
                               }
                               return res.json();
                             }).then(data => {
                               const end = Date.now();
                               setTestStatus('success');
                               setTestMessage(`连接成功，模型响应正常！延迟: ${end - start}ms`);
                             }).catch(err => {
                               setTestStatus('error');
                               setTestMessage(`${err.message}`);
                             });
                           }}
                           disabled={testStatus === 'loading'}
                           className="w-full bg-[var(--theme-accent-1)] text-white text-[15px] font-medium py-3.5 rounded-2xl transition-all hover:opacity-90 active:scale-[0.98] shadow-lg shadow-[var(--theme-accent-1)]/20 disabled:opacity-50 disabled:cursor-not-allowed"
                         >
                           {testStatus === 'loading' ? '测试中...' : '开始测试'}
                         </button>
                       </div>
                    </div>
                  )}

                  {deletingProvider && (
                    <div className="absolute inset-0 z-50 bg-[#F3F4F6]/80 dark:bg-[#1a1c1e]/80 backdrop-blur-sm flex flex-col items-center justify-center p-6 animate-in fade-in duration-200 rounded-[32px]">
                      <div className="bg-white dark:bg-[#2a2d30] w-full max-w-sm rounded-[28px] overflow-hidden shadow-2xl animate-in zoom-in-95 duration-200 border border-black/5 dark:border-white/5">
                        <div className="p-6 pb-4">
                          <h3 className="text-[17px] font-medium text-center mb-2">删除提供商</h3>
                          <p className="text-[14px] opacity-60 text-center leading-relaxed">
                            确定要删除提供商 "{deletingProvider}" 吗？此操作无法撤销。
                          </p>
                        </div>
                        <div className="flex gap-3 p-6 pt-2">
                          <button 
                            onClick={() => setDeletingProvider(null)}
                            className="flex-1 py-3.5 rounded-2xl bg-black/5 dark:bg-white/5 text-[15px] font-medium transition-all hover:bg-black/10 dark:hover:bg-white/10 active:scale-[0.98]"
                          >
                            取消
                          </button>
                          <button 
                            onClick={() => {
                              setProviders(prev => {
                                const next = prev.filter(p => p.name !== deletingProvider);
                                localStorage.setItem('ai_providers', JSON.stringify(next));
                                return next;
                              });
                              setDeletingProvider(null);
                            }}
                            className="flex-1 py-3.5 rounded-2xl bg-red-500 text-white text-[15px] font-medium transition-all hover:bg-red-600 active:scale-[0.98] shadow-lg shadow-red-500/20"
                          >
                            删除
                          </button>
                        </div>
                      </div>
                    </div>
                  )}

                </div>
              )}
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
