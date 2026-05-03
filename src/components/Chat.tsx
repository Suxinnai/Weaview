import React, { useState, useRef, useEffect } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { Send, Plus, Mic, Image as ImageIcon, FileText, Settings, Menu, X, User, ChevronRight, Zap } from 'lucide-react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';
import { useTheme } from './ThemeProvider';
import { streamChat, type Message, DEFAULT_SYSTEM_INSTRUCTION } from '../services/ai';
import { cn } from '../lib/utils';
import 'katex/dist/katex.min.css';
import { SettingsSheet } from './SettingsSheet';

export interface ChatSession {
  id: string;
  title: string;
  updatedAt: number;
  messages: Message[];
}

export function Chat() {
  const { theme, setTheme, themeUpdateKey, resolvedTheme, setThemeMode } = useTheme();
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputValue, setInputValue] = useState('');
  const [inputHeight, setInputHeight] = useState(44);
  const [isStreaming, setIsStreaming] = useState(false);
  const [dockExpanded, setDockExpanded] = useState(false);
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const [systemPrompt, setSystemPrompt] = useState(() => localStorage.getItem('system_prompt') || DEFAULT_SYSTEM_INSTRUCTION);
  const [emotionEnabled, setEmotionEnabled] = useState(() => localStorage.getItem('emotion_enabled') !== 'false');
  const [globalMemoryEnabled, setGlobalMemoryEnabled] = useState(() => localStorage.getItem('global_memory_enabled') !== 'false');
  const [referenceHistoryEnabled, setReferenceHistoryEnabled] = useState(() => localStorage.getItem('reference_history_enabled') !== 'false');
  const [assistantAvatar, setAssistantAvatar] = useState(() => localStorage.getItem('assistant_avatar') || '');
  const [userAvatar, setUserAvatar] = useState(() => localStorage.getItem('user_avatar') || '');
  const [userName, setUserName] = useState(() => localStorage.getItem('user_name') || '织梦者');
  
  const [isModelDropdownOpen, setIsModelDropdownOpen] = useState(false);
  const [modelSearchQuery, setModelSearchQuery] = useState('');
  const [providers, setProviders] = useState<{name: string, models?: {id: string, name: string}[]}[]>(() => {
    const saved = localStorage.getItem('ai_providers');
    return saved ? JSON.parse(saved) : [];
  });
  const [chatModelAssignment, setChatModelAssignment] = useState<{provider: string, model: string}>(() => {
    const saved = localStorage.getItem('ai_model_assignments');
    if (saved) {
      const parsed = JSON.parse(saved);
      if (parsed.chat) return parsed.chat;
    }
    return { provider: '', model: '' };
  });

  const [chatSessions, setChatSessions] = useState<ChatSession[]>(() => {
    try {
      const saved = localStorage.getItem('chat_sessions');
      return saved ? JSON.parse(saved) : [];
    } catch {
      return [];
    }
  });
  const [currentSessionId, setCurrentSessionId] = useState<string | null>(null);

  useEffect(() => {
    if (messages.length === 0) return;

    let activeId = currentSessionId;
    if (!activeId) {
      activeId = Date.now().toString();
      setCurrentSessionId(activeId);
    }
    
    // First message as title if there's only one user message initially
    const title = messages.find(m => m.role === 'user')?.content.slice(0, 20) || '未命名梦境';

    setChatSessions(prev => {
      const existingIndex = prev.findIndex(s => s.id === activeId);
      const updatedSession: ChatSession = {
        id: activeId!,
        title,
        updatedAt: Date.now(),
        messages
      };
      
      let newSessions;
      if (existingIndex >= 0) {
        newSessions = [updatedSession, ...prev.filter((_, i) => i !== existingIndex)];
      } else {
        newSessions = [updatedSession, ...prev];
      }
      localStorage.setItem('chat_sessions', JSON.stringify(newSessions));
      return newSessions;
    });
  }, [messages]);

  const [isRecording, setIsRecording] = useState(false);
  const recognitionRef = useRef<any>(null);
  const initialInputRef = useRef('');

  const toggleRecording = () => {
    if (isRecording) {
      if (recognitionRef.current) {
        recognitionRef.current.stop();
      }
      setIsRecording(false);
      return;
    }

    const SpeechRecognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
    if (!SpeechRecognition) {
      console.error("您的浏览器不支持语音输入功能");
      setInputValue("【错误：您的浏览器不支持语音输入功能或未开启麦克风权限】");
      setTimeout(() => setInputValue(""), 3000);
      return;
    }

    if (!recognitionRef.current) {
      const recognition = new SpeechRecognition();
      recognition.continuous = true;
      recognition.interimResults = true;
      recognition.lang = 'zh-CN';

      recognition.onresult = (event: any) => {
        let transcript = '';
        for (let i = event.resultIndex; i < event.results.length; ++i) {
          transcript += event.results[i][0].transcript;
        }
        setInputValue(initialInputRef.current + (initialInputRef.current && transcript ? ' ' : '') + transcript);
      };

      recognition.onerror = (event: any) => {
        console.error("Speech recognition error", event.error);
        if (event.error === 'not-allowed') {
          setInputValue("【错误：麦克风权限被拒绝，请在浏览器地址栏允许麦克风权限】");
          setTimeout(() => setInputValue(""), 4000);
        }
        setIsRecording(false);
      };

      recognition.onend = () => {
        setIsRecording(false);
      };

      recognitionRef.current = recognition;
    }

    try {
      initialInputRef.current = inputValue;
      recognitionRef.current.start();
      setIsRecording(true);
    } catch (e) {
      console.error("Failed to start speech recognition:", e);
      setIsRecording(false);
    }
  };

  const messagesEndRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth', block: 'end' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages, isStreaming]);

  const handleSubmit = async (e?: React.FormEvent) => {
    e?.preventDefault();
    if (!inputValue.trim() || isStreaming) return;

    if (isRecording) {
      if (recognitionRef.current) {
        recognitionRef.current.stop();
      }
      setIsRecording(false);
    }

    const newUserMsg: Message = { role: 'user', content: inputValue };
    const newMessages = [...messages, newUserMsg];
    setMessages(newMessages);
    setInputValue('');
    setIsStreaming(true);

    // reset textarea height and fix ios safari layout issue
    setInputHeight(44);
    const textarea = document.getElementById('chat-textarea');
    if (textarea) {
      textarea.style.height = '44px';
      textarea.blur();
    }
    setTimeout(() => {
      window.scrollTo({ top: 0, left: 0, behavior: 'smooth' });
    }, 10);

    try {
      // Create a temporary model message
      setMessages((prev) => [...prev, { role: 'model', content: '' }]);
      
      let memories: string[] = [];
      try {
        const saved = localStorage.getItem('ai_memories');
        if (saved) memories = JSON.parse(saved);
      } catch (e) {}
      
      let currentPrompt = emotionEnabled ? `${systemPrompt}\n\n[System directive: Emotion and poetry mode is ENABLED. Your responses should be highly emotional, vivid, and deeply artistic. Do not just output plain facts.]` : systemPrompt;
      if (globalMemoryEnabled && memories.length > 0) {
        currentPrompt += `\n\n[System directive: You have the following memories about the user:\n${memories.map(m => `- ${m}`).join('\n')}\nPlease take them into account when responding.]`;
      }
      
      const stream = streamChat(newMessages, (themeArgs) => {
        setTheme({
          backgroundColor: themeArgs.backgroundColor,
          textColor: themeArgs.textColor,
          fontFamily: themeArgs.fontFamily as 'sans' | 'serif',
          isDark: themeArgs.isDark,
        });
        // Let the AI overwrite the user's manual dark mode if it explicitly specifies one
        if (themeArgs.isDark !== undefined) {
          setThemeMode(themeArgs.isDark ? 'dark' : 'light');
        }
      }, currentPrompt);

      let fullResponse = '';
      for await (const chunk of stream) {
        fullResponse += chunk;
        setMessages((prev) => {
          const updated = [...prev];
          updated[updated.length - 1] = {
            ...updated[updated.length - 1],
            content: fullResponse
          };
          return updated;
        });
      }
    } catch (error) {
      console.error(error);
    } finally {
      setIsStreaming(false);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.nativeEvent.isComposing) return;
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmit();
    }
  };

  return (
    <div className="relative flex-1 w-full h-full flex flex-col overflow-hidden text-[var(--theme-text)]">
      
      {/* Theme Update Ripple Effect */}
      <AnimatePresence>
        {themeUpdateKey > 0 && (
          <motion.div
            key={`ripple-${themeUpdateKey}`}
            initial={{ scale: 0, opacity: 0.3 }}
            animate={{ scale: 3, opacity: 0 }}
            transition={{ duration: 1.5, ease: "easeOut" }}
            className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[100vw] h-[100vw] rounded-full mix-blend-overlay pointer-events-none z-10"
            style={{ backgroundColor: theme.textColor }}
          />
        )}
      </AnimatePresence>

      {/* Ambient Lighting Effects */}
      <div className="absolute top-[-50px] left-[-50px] md:top-[-100px] md:left-[-100px] w-[300px] h-[300px] md:w-[500px] md:h-[500px] rounded-full bg-gradient-to-br from-[var(--theme-accent-1)] to-transparent opacity-20 blur-[60px] md:blur-[80px] pointer-events-none z-0"></div>
      <div className="absolute bottom-[-30px] right-[-30px] md:bottom-[-50px] md:right-[-50px] w-[250px] h-[250px] md:w-[400px] md:h-[400px] rounded-full bg-gradient-to-tl from-[var(--theme-accent-2)] to-transparent opacity-25 blur-[40px] md:blur-[60px] pointer-events-none z-0"></div>

      {/* Mobile Sidebar overlay & drawer */}
      <AnimatePresence>
        {isSidebarOpen && (
          <>
            <motion.div 
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => setIsSidebarOpen(false)}
              className="absolute inset-0 bg-black/10 dark:bg-black/40 backdrop-blur-sm z-40"
            />
            <motion.div
              initial={{ x: '-100%' }}
              animate={{ x: 0 }}
              exit={{ x: '-100%' }}
              transition={{ type: 'spring', damping: 28, stiffness: 250 }}
              className="absolute top-0 left-0 w-[280px] h-full bg-white/90 dark:bg-[#1a1c1e]/90 backdrop-blur-2xl z-50 pt-safe flex flex-col shadow-2xl border-r border-black/5 dark:border-white/5"
            >
              <div className="p-6 flex items-center justify-between opacity-80">
                 <span className="text-sm font-medium tracking-widest uppercase flex items-center gap-2">
                   <div className="w-6 h-6 rounded-full border border-[var(--theme-accent-1)] flex items-center justify-center p-0.5">
                     <div className="w-full h-full rounded-full bg-gradient-to-tr from-[var(--theme-accent-1)] to-[var(--theme-accent-2)]"></div>
                   </div>
                   织境
                 </span>
                 <button onClick={() => setIsSidebarOpen(false)} className="p-2 -mr-2 opacity-60 hover:opacity-100 transition-opacity">
                   <X className="w-5 h-5"/>
                 </button>
              </div>
              
              <div className="px-6 mb-4">
                <button 
                  onClick={() => {
                    setMessages([]);
                    setCurrentSessionId(null);
                    setIsSidebarOpen(false);
                  }}
                  className="w-full py-3 px-4 rounded-2xl bg-[var(--theme-accent-1)]/10 text-[13px] font-medium flex items-center justify-center gap-2 hover:bg-[var(--theme-accent-1)]/20 transition-colors"
                >
                  <Plus className="w-4 h-4" /> 新的织梦
                </button>
              </div>

              {/* History List */}
              <div className="flex-1 overflow-y-auto px-4 py-2 flex flex-col gap-1 no-scrollbar">
                 <div className="text-[10px] font-medium opacity-40 uppercase tracking-widest mb-2 px-3 mt-4">历史梦境</div>
                 {chatSessions.map((session) => (
                   <button 
                     key={session.id} 
                     onClick={() => {
                       setMessages(session.messages);
                       setCurrentSessionId(session.id);
                       setIsSidebarOpen(false);
                     }}
                     className={cn(
                       "text-left px-4 py-3 text-[14px] rounded-2xl transition-colors truncate",
                       currentSessionId === session.id 
                         ? "bg-black/10 dark:bg-white/10 opacity-100 font-medium"
                         : "opacity-70 hover:opacity-100 hover:bg-black/5 dark:hover:bg-white/5"
                     )}
                   >
                     {session.title}
                   </button>
                 ))}
                 {chatSessions.length === 0 && (
                   <div className="px-4 py-3 text-[12px] opacity-40 text-center">暂无历史记录</div>
                 )}
              </div>
              
              {/* User Info */}
              <div className="p-3 mb-safe mx-4 mb-4 rounded-3xl bg-black/5 dark:bg-white/5 flex items-center gap-3">
                 <div className="w-10 h-10 shrink-0 rounded-full bg-gradient-to-tr from-[var(--theme-accent-1)] to-[var(--theme-accent-2)] flex items-center justify-center shadow-inner overflow-hidden">
                   {userAvatar ? (
                     <img src={userAvatar} alt="User Avatar" className="w-full h-full object-cover" />
                   ) : (
                     <User className="w-5 h-5 opacity-60 mix-blend-overlay" />
                   )}
                 </div>
                 <div className="flex flex-col overflow-hidden flex-1">
                   <span className="text-[13px] font-medium truncate">{userName}</span>
                   <span className="text-[10px] opacity-40">Pro Plan</span>
                 </div>
                 <button 
                   onClick={() => {
                     setIsSidebarOpen(false);
                     setTimeout(() => setIsSettingsOpen(true), 300);
                   }}
                   className="w-8 h-8 rounded-full flex items-center justify-center hover:bg-black/5 dark:hover:bg-white/10 transition-colors"
                 >
                   <Settings className="w-4 h-4 opacity-60" />
                 </button>
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>

      <SettingsSheet 
        isOpen={isSettingsOpen} 
        onClose={() => setIsSettingsOpen(false)} 
        systemPrompt={systemPrompt}
        setSystemPrompt={(val) => {
          setSystemPrompt(val);
          localStorage.setItem('system_prompt', val);
        }}
        emotionEnabled={emotionEnabled}
        setEmotionEnabled={(val) => {
          setEmotionEnabled(val);
          localStorage.setItem('emotion_enabled', val.toString());
        }}
        globalMemoryEnabled={globalMemoryEnabled}
        setGlobalMemoryEnabled={(val) => {
          setGlobalMemoryEnabled(val);
          localStorage.setItem('global_memory_enabled', val.toString());
        }}
        referenceHistoryEnabled={referenceHistoryEnabled}
        setReferenceHistoryEnabled={(val) => {
          setReferenceHistoryEnabled(val);
          localStorage.setItem('reference_history_enabled', val.toString());
        }}
        assistantAvatar={assistantAvatar}
        setAssistantAvatar={(val) => {
          setAssistantAvatar(val);
          localStorage.setItem('assistant_avatar', val);
        }}
        userAvatar={userAvatar}
        setUserAvatar={(val) => {
          setUserAvatar(val);
          if (val) localStorage.setItem('user_avatar', val);
          else localStorage.removeItem('user_avatar');
        }}
        userName={userName}
        setUserName={(val) => {
          setUserName(val);
          localStorage.setItem('user_name', val);
        }}
      />

      {/* Top Navigation / Header */}
      <header className="absolute top-0 w-full pt-safe flex items-center justify-center z-10 pointer-events-none">
        <div className="flex w-full max-w-4xl items-center justify-center px-4 h-14 mt-2 relative">
          <div className="absolute left-4 top-1/2 -translate-y-1/2 flex items-center gap-2 pointer-events-auto">
            <button 
              onClick={() => setIsSidebarOpen(true)}
              className="w-10 h-10 shrink-0 rounded-full flex items-center justify-center hover:bg-black/5 dark:hover:bg-white/5 transition-colors"
            >
              <Menu className="w-5 h-5 opacity-60" />
            </button>
          </div>
          
          <div className="flex items-center pointer-events-auto relative">
            <button 
              onClick={() => setIsModelDropdownOpen(!isModelDropdownOpen)}
              className="flex flex-col items-center justify-center px-4 py-1 rounded-xl hover:bg-black/5 dark:hover:bg-white/5 transition-colors group"
            >
              <span className="text-[15px] font-medium tracking-wide">
                {messages.length > 0 ? (chatSessions.find(s => s.id === currentSessionId)?.title || "未命名梦境") : "新梦境"}
              </span>
              <div className="flex items-center gap-1.5 mt-0.5 opacity-50 group-hover:opacity-100 transition-opacity max-w-full">
                <div className="w-1 h-1 rounded-full bg-[var(--theme-accent-1)] animate-pulse shadow-[0_0_4px_var(--theme-accent-1)] shrink-0"></div>
                <span className="text-[10px] font-medium uppercase tracking-widest truncate max-w-[150px] shrink-0">{chatModelAssignment.model || 'Gemini 2.5 Pro'}</span>
                <ChevronRight className={`w-3 h-3 -ml-1 opacity-60 shrink-0 transition-transform ${isModelDropdownOpen ? '-rotate-90' : 'rotate-90'}`} />
              </div>
            </button>

            {isModelDropdownOpen && (
              <>
                <div 
                  className="fixed inset-0 z-40" 
                  onClick={() => setIsModelDropdownOpen(false)}
                />
                <div className="absolute top-full mt-2 left-1/2 -translate-x-1/2 w-[240px] bg-white dark:bg-[#1a1b1e] border border-black/5 dark:border-white/5 shadow-xl rounded-2xl p-2 z-50">
                  <div className="text-[11px] font-bold tracking-widest uppercase opacity-40 px-3 py-2 mb-1 flex items-center justify-between">
                    选择模型
                  </div>
                  <div className="px-2 pb-2">
                    <input
                      type="text"
                      placeholder="搜索模型..."
                      value={modelSearchQuery}
                      onChange={(e) => setModelSearchQuery(e.target.value)}
                      className="w-full bg-black/5 dark:bg-white/5 border border-transparent focus:border-[var(--theme-accent-1)]/50 text-[12px] px-3 py-2 rounded-xl outline-none transition-colors"
                      autoFocus
                    />
                  </div>
                  <div className="max-h-[300px] overflow-y-auto no-scrollbar space-y-1">
                    {providers.flatMap(p => 
                      (p.models || []).filter(m => m.name.toLowerCase().includes(modelSearchQuery.toLowerCase()) || p.name.toLowerCase().includes(modelSearchQuery.toLowerCase())).map(m => (
                        <button
                          key={`${p.name}-${m.id}`}
                          onClick={() => {
                            const next = { provider: p.name, model: m.name };
                            setChatModelAssignment(next);
                            
                            // Save to localStorage
                            const saved = localStorage.getItem('ai_model_assignments');
                            let assignments = saved ? JSON.parse(saved) : {};
                            assignments.chat = next;
                            localStorage.setItem('ai_model_assignments', JSON.stringify(assignments));
                            
                            setIsModelDropdownOpen(false);
                            setModelSearchQuery('');
                          }}
                          className={`w-full text-left px-3 py-2.5 rounded-xl text-[14px] transition-colors flex items-center justify-between ${
                            chatModelAssignment.model === m.name && chatModelAssignment.provider === p.name
                              ? 'bg-[var(--theme-accent-1)]/10 text-[var(--theme-accent-1)] font-medium'
                              : 'hover:bg-black/5 dark:hover:bg-white/5'
                          }`}
                        >
                          <div className="flex flex-col truncate pr-2">
                            <span className="truncate">{m.name}</span>
                            <span className="text-[10px] opacity-40 uppercase tracking-wider mt-0.5">{p.name}</span>
                          </div>
                          {chatModelAssignment.model === m.name && chatModelAssignment.provider === p.name && (
                            <div className="w-1.5 h-1.5 rounded-full bg-[var(--theme-accent-1)] shrink-0" />
                          )}
                        </button>
                      ))
                    )}
                    {providers.flatMap(p => p.models || []).filter(m => m.name.toLowerCase().includes(modelSearchQuery.toLowerCase())).length === 0 && (
                      <div className="px-3 py-4 text-center">
                        <span className="text-[13px] opacity-50 block mb-2">{providers.flatMap(p => p.models || []).length === 0 ? '未配置可用模型' : '未找到匹配模型'}</span>
                        <button 
                          onClick={() => {
                            setIsModelDropdownOpen(false);
                            setIsSettingsOpen(true);
                          }}
                          className="text-[12px] font-medium text-[var(--theme-accent-1)] hover:underline"
                        >
                          前往设置配置
                        </button>
                      </div>
                    )}
                  </div>
                </div>
              </>
            )}
          </div>
        </div>
      </header>

      {/* Main Chat Area */}
      <div className="flex-1 overflow-y-auto no-scrollbar scroll-smooth px-4 md:px-6 pb-4 pt-28 z-0">
        {messages.length === 0 ? (
          <div className="h-full flex flex-col items-center justify-center opacity-80">
            <motion.p 
              initial={{ y: 20, opacity: 0 }}
              animate={{ y: 0, opacity: 1 }}
              transition={{ delay: 0.5, duration: 1 }}
              className="text-[16px] md:text-[18px] tracking-[0.1em] font-light px-4 text-center"
            >
              今天，你想编织什么梦境？
            </motion.p>
            <motion.p 
              initial={{ y: 20, opacity: 0 }}
              animate={{ y: 0, opacity: 1 }}
              transition={{ delay: 1, duration: 1 }}
              className="mt-3 text-[12px] md:text-[13px] tracking-wide opacity-40 px-4 text-center"
            >
              What dream shall we weave today?
            </motion.p>
          </div>
        ) : (
          <div className="flex flex-col gap-10 md:gap-12 max-w-3xl mx-auto w-full pb-10">
            {messages.map((msg, idx) => (
              <motion.div
                key={idx}
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                className={cn(
                  "flex w-full",
                  msg.role === 'user' ? "justify-end" : "justify-start"
                )}
              >
                {msg.role === 'user' ? (
                   // User message: Subtle tint, right aligned
                  <div className="max-w-[85%] md:max-w-[80%] rounded-[24px] md:rounded-[32px] rounded-tr-[8px] md:rounded-tr-[8px] px-4 py-3 md:px-6 md:py-4 text-[14px] md:text-[15px] leading-relaxed relative border backdrop-blur-sm shadow-sm whitespace-pre-wrap"
                       style={{ 
                         backgroundColor: resolvedTheme === 'dark' ? 'rgba(255,255,255,0.05)' : 'rgba(181,234,234,0.1)',
                         borderColor: resolvedTheme === 'dark' ? 'rgba(255,255,255,0.1)' : 'rgba(255,255,255,0.8)',
                         color: theme.textColor
                       }}>
                    {msg.content}
                  </div>
                ) : (
                  // AI message: borderless, left aligned, floating
                  <div className="flex items-start gap-3 md:gap-6 max-w-[95%] md:max-w-[85%] text-[15px] leading-loose markdown-body group relative mt-2">
                    <div className="mt-2.5 shrink-0">
                      {assistantAvatar ? (
                        <div className="w-6 h-6 -mt-2 rounded-full overflow-hidden border border-[var(--theme-accent-1)]/30 flex items-center justify-center select-none shadow-[0_0_10px_rgba(181,234,234,0.2)]">
                          <img src={assistantAvatar} alt="Assistant Avatar" className="w-full h-full object-cover pointer-events-none" />
                        </div>
                      ) : (
                        <div className="w-1.5 h-1.5 rounded-full bg-gradient-to-tr from-[var(--theme-accent-1)] to-[var(--theme-accent-2)] shadow-[0_0_10px_rgba(181,234,234,0.8)]"></div>
                      )}
                    </div>
                    <div className="flex-1 w-full overflow-hidden">
                      <ReactMarkdown 
                        remarkPlugins={[remarkGfm, remarkMath]} 
                        rehypePlugins={[rehypeKatex]}
                      >
                        {msg.content}
                      </ReactMarkdown>
                    </div>
                  </div>
                )}
              </motion.div>
            ))}
            
            {/* Typing indicator */}
            {isStreaming && messages[messages.length - 1]?.role !== 'model' && (
               <motion.div
                 initial={{ opacity: 0 }} animate={{ opacity: 1 }}
                 className="flex justify-start w-full opacity-60 pl-4 md:pl-8"
               >
                 <div className="relative pl-2">
                   <div className="w-1.5 h-1.5 rounded-full bg-current shadow-[0_0_8px_currentColor] animate-pulse" />
                 </div>
               </motion.div>
            )}
            
            {/* Dynamic spacer to push messages above the absolute footer */}
            <div 
               style={{ height: `${inputHeight + (dockExpanded ? 100 : 40)}px` }} 
               className="w-full shrink-0 transition-all duration-300"
            />
            <div ref={messagesEndRef} />
          </div>
        )}
      </div>

      {/* Input Dock */}
      <footer className="absolute bottom-4 left-0 w-full pb-safe flex justify-center z-20 pointer-events-none px-4">
        <form 
          onSubmit={handleSubmit}
          className={cn(
            "pointer-events-auto w-full max-w-3xl flex-col bg-white/80 dark:bg-black/60 backdrop-blur-2xl border border-white dark:border-white/5 shadow-[0_12px_40px_rgba(0,0,0,0.06)] transition-all duration-300 relative z-40 overflow-hidden",
            dockExpanded ? "rounded-[24px]" : "rounded-[32px]"
          )}
        >
          <AnimatePresence>
            {isRecording && (
              <motion.div
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: 40, opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                className="flex items-center justify-center gap-1 w-full bg-[#10B981]/10 rounded-t-[24px] overflow-hidden border-b border-black/5 dark:border-white/5"
              >
                {[1, 2, 3, 4, 5, 6, 7].map(i => (
                  <motion.div
                    key={i}
                    animate={{ height: [10, Math.random() * 15 + 15, 10] }}
                    transition={{
                      repeat: Infinity,
                      duration: 0.8,
                      delay: i * 0.15,
                      ease: "easeInOut"
                    }}
                    className="w-1.5 bg-[#10B981] rounded-full"
                  />
                ))}
                <span className="text-[12px] text-[#10B981] font-medium ml-2 uppercase tracking-widest animate-pulse">聆听中...</span>
              </motion.div>
            )}
          </AnimatePresence>
          <div className="flex items-end w-full p-1.5">
            <button 
              type="button"
              onClick={() => setDockExpanded(!dockExpanded)}
              className={cn(
                "w-10 h-10 shrink-0 rounded-full flex items-center justify-center transition-all duration-300 mb-0.5",
                dockExpanded ? "opacity-100 bg-black/5 dark:bg-white/10 backdrop-blur-md" : "opacity-50 hover:opacity-100"
              )}
              style={{ transform: dockExpanded ? "rotate(45deg)" : "rotate(0deg)" }}
            >
              <Plus className="w-5 h-5 outline-none" />
            </button>
            
            <textarea
              id="chat-textarea"
              value={inputValue}
              onChange={(e) => {
                setInputValue(e.target.value);
                e.target.style.height = '44px';
                const newHeight = Math.min(e.target.scrollHeight, 120);
                e.target.style.height = `${newHeight}px`;
                setInputHeight(newHeight);
              }}
              onKeyDown={handleKeyDown}
              placeholder="今天想编织什么？"
              className="flex-1 bg-transparent border-none outline-none px-2 py-[10px] text-[15px] leading-relaxed resize-none no-scrollbar min-h-[44px] max-h-[120px] mr-1"
              style={{ height: '44px' }}
            />
            
            <div className="flex items-center gap-1 mr-1 mb-0.5 shrink-0">
               {/* Only show mic if input is empty or currently recording */}
               {(!inputValue.trim() || isRecording) && !isStreaming && (
                 <button 
                   type="button" 
                   onClick={toggleRecording}
                   className={`w-9 h-9 shrink-0 rounded-full flex items-center justify-center transition-all ${isRecording ? 'opacity-100 bg-[#10B981]/20 text-[#10B981]' : 'opacity-40 hover:opacity-100 text-current'}`}
                 >
                   <Mic className="w-4 h-4" />
                 </button>
               )}
               
               {(inputValue.trim() || isStreaming) && !isRecording ? (
                  <button 
                     type="submit" 
                     disabled={!inputValue.trim() || isStreaming}
                     className="px-5 h-9 shrink-0 rounded-full bg-[#10B981] text-white shadow-sm shadow-[#10B981]/40 text-[14px] font-medium tracking-wide hover:bg-[#059669] disabled:opacity-50 transition-all"
                  >
                    编织
                  </button>
               ) : (
                  <div className="px-5 h-9 shrink-0 rounded-full bg-black/5 dark:bg-white/10 text-[var(--theme-text)]/30 text-[14px] font-medium tracking-wide flex items-center justify-center pointer-events-none transition-colors">
                    编织
                  </div>
               )}
            </div>
          </div>
          
          {/* Expanded Tools */}
          <AnimatePresence>
            {dockExpanded && (
              <motion.div
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: 'auto', opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                className="overflow-hidden"
              >
                <div className="flex items-center gap-2 md:gap-4 px-4 pb-3 pt-3 mt-1 border-t border-black/5 dark:border-white/5 mx-1">
                  {[
                    { icon: ImageIcon, label: '图片' },
                    { icon: FileText, label: '文件' }
                  ].map((tool, i) => (
                    <button 
                      key={i} 
                      type="button"
                      className="flex items-center gap-2.5 px-4 py-2.5 rounded-xl bg-black/5 dark:bg-white/5 hover:bg-black/10 dark:hover:bg-white/10 transition-colors"
                    >
                      <tool.icon className="w-4 h-4 opacity-70" />
                      <span className="text-[13px] font-medium opacity-80">{tool.label}</span>
                    </button>
                  ))}
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </form>
      </footer>

      {/* Breathing Wait State (Hidden Indicator) */}
      {isStreaming && (
        <div className="absolute bottom-0 left-0 w-full h-1 bg-gradient-to-r from-transparent via-[var(--theme-accent-1)]/40 to-transparent animate-pulse pointer-events-none z-30"></div>
      )}

    </div>
  );
}
