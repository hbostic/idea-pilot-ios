import { useState } from "react";
import { Play, PlusCircle, Layers, Settings } from "lucide-react";
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";
import { AnimatePresence, motion } from "framer-motion";
import { Drawer } from "vaul";
import { Playbook, MOCK_PLAYBOOKS } from "./types";
import { PlaybookHome } from "./PlaybookHome";
import { CaptureSheet } from "./CaptureSheet";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function AppLayout() {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [activeTab, setActiveTab] = useState<"NOW" | "Playbooks">("NOW");
  const [activePlaybookId, setActivePlaybookId] = useState<string | null>("1");
  const [playbooks, setPlaybooks] = useState<Playbook[]>(MOCK_PLAYBOOKS);
  const [isCaptureOpen, setIsCaptureOpen] = useState(false);
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);

  if (!isAuthenticated) {
    return <AuthScreen onLogin={() => setIsAuthenticated(true)} />;
  }

  const activePlaybook = playbooks.find(p => p.id === activePlaybookId);

  return (
    <div className="fixed inset-0 bg-black flex justify-center overflow-hidden">
      <div className="w-full h-full max-w-md bg-black relative flex flex-col shadow-2xl overflow-hidden border-x border-white/5">
        
        {/* Main Content Area */}
        <div className="flex-1 overflow-y-auto no-scrollbar pb-24">
          <AnimatePresence mode="wait">
            {activeTab === "NOW" ? (
              <motion.div
                key="tab-now"
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: 20 }}
                transition={{ duration: 0.2 }}
                className="h-full"
              >
                {activePlaybook ? (
                  <PlaybookHome 
                    playbook={activePlaybook} 
                    onUpdate={(updated) => setPlaybooks(playbooks.map(p => p.id === updated.id ? updated : p))}
                    onOpenSections={() => {}}
                    onOpenWeeklyPlan={() => {}}
                  />
                ) : (
                  <EmptyNowState onGoToPlaybooks={() => setActiveTab("Playbooks")} />
                )}
              </motion.div>
            ) : (
              <motion.div
                key="tab-playbooks"
                initial={{ opacity: 0, x: 20 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: -20 }}
                transition={{ duration: 0.2 }}
                className="h-full"
              >
                <PlaybookList 
                  playbooks={playbooks} 
                  onSelect={(id) => {
                    setActivePlaybookId(id);
                    setActiveTab("NOW");
                  }}
                  onOpenSettings={() => setIsSettingsOpen(true)}
                />
              </motion.div>
            )}
          </AnimatePresence>
        </div>

        {/* Tab Bar */}
        <div className="absolute bottom-0 w-full ios-glass safe-bottom px-6 py-2 flex justify-between items-center z-40">
          <TabButton 
            icon={<Play size={24} className={activeTab === "NOW" ? "fill-primary text-primary" : ""} />} 
            label="Now" 
            isActive={activeTab === "NOW"} 
            onClick={() => setActiveTab("NOW")} 
          />
          <button 
            onClick={() => setIsCaptureOpen(true)}
            className="flex flex-col items-center justify-center p-2 text-muted-foreground hover:text-white transition-colors relative group"
            data-testid="tab-capture"
          >
            <div className="bg-primary/20 p-3 rounded-full text-primary group-hover:bg-primary group-hover:text-white transition-all">
              <PlusCircle size={28} />
            </div>
          </button>
          <TabButton 
            icon={<Layers size={24} className={activeTab === "Playbooks" ? "fill-white text-white" : ""} />} 
            label="Playbooks" 
            isActive={activeTab === "Playbooks"} 
            onClick={() => setActiveTab("Playbooks")} 
          />
        </div>

        <CaptureSheet 
          isOpen={isCaptureOpen} 
          onOpenChange={setIsCaptureOpen} 
          playbookId={activePlaybookId}
          onAdd={(task) => {
            if (activePlaybookId) {
              setPlaybooks(playbooks.map(p => {
                if (p.id === activePlaybookId) {
                  return { ...p, tasks: [...p.tasks, task] };
                }
                return p;
              }));
            }
          }}
        />
        
        <Drawer.Root open={isSettingsOpen} onOpenChange={setIsSettingsOpen}>
          <Drawer.Portal>
            <Drawer.Overlay className="fixed inset-0 bg-black/60 z-50 backdrop-blur-sm" />
            <Drawer.Content className="bg-card flex flex-col rounded-t-3xl mt-24 fixed bottom-0 left-0 right-0 max-w-md mx-auto z-50 border-t border-white/10 outline-none">
              <div className="p-4 bg-card rounded-t-3xl flex-1 safe-bottom">
                <div className="mx-auto w-12 h-1.5 flex-shrink-0 rounded-full bg-white/20 mb-8" />
                <h2 className="text-2xl font-bold mb-6 px-2">Settings</h2>
                <div className="space-y-4 px-2">
                  <button 
                    onClick={() => setIsAuthenticated(false)}
                    className="w-full text-left px-4 py-4 rounded-xl bg-secondary/50 text-destructive font-medium border border-white/5 active:scale-[0.98] transition-all"
                  >
                    Sign Out
                  </button>
                </div>
              </div>
            </Drawer.Content>
          </Drawer.Portal>
        </Drawer.Root>
      </div>
    </div>
  );
}

function TabButton({ icon, label, isActive, onClick }: { icon: React.ReactNode, label: string, isActive: boolean, onClick: () => void }) {
  return (
    <button 
      onClick={onClick}
      className={cn(
        "flex flex-col items-center justify-center p-2 w-16 transition-colors",
        isActive ? "text-primary" : "text-muted-foreground hover:text-white"
      )}
    >
      {icon}
      <span className={cn("text-[10px] mt-1 font-medium", isActive ? "opacity-100" : "opacity-0")}>{label}</span>
    </button>
  );
}

function AuthScreen({ onLogin }: { onLogin: () => void }) {
  const [isLogin, setIsLogin] = useState(true);
  
  return (
    <div className="w-full h-full max-w-md mx-auto bg-black relative flex flex-col p-6 safe-top border-x border-white/5">
      <div className="flex-1 flex flex-col justify-center">
        <div className="mb-12">
          <div className="w-12 h-12 bg-primary rounded-2xl flex items-center justify-center mb-6 shadow-[0_0_30px_rgba(var(--primary),0.3)]">
            <Play className="text-white fill-white ml-1" size={24} />
          </div>
          <h1 className="text-4xl font-bold tracking-tight mb-2">Idea Pilot</h1>
          <p className="text-muted-foreground text-lg">Execution surface for your playbooks.</p>
        </div>
        
        <div className="space-y-4">
          <div className="space-y-2">
            <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider pl-1">Email</label>
            <input 
              type="email" 
              placeholder="you@example.com"
              className="w-full bg-secondary/50 border border-white/10 rounded-xl px-4 py-4 text-white placeholder:text-muted-foreground focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-all"
            />
          </div>
          <div className="space-y-2">
            <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider pl-1">Password</label>
            <input 
              type="password" 
              placeholder="••••••••"
              className="w-full bg-secondary/50 border border-white/10 rounded-xl px-4 py-4 text-white placeholder:text-muted-foreground focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-all"
            />
          </div>
          
          <button 
            onClick={onLogin}
            className="w-full bg-primary text-white font-semibold rounded-xl px-4 py-4 mt-4 active:scale-[0.98] transition-all shadow-[0_4px_20px_rgba(var(--primary),0.4)]"
            data-testid="button-signin"
          >
            {isLogin ? "Sign In" : "Create Account"}
          </button>
        </div>
        
        <div className="mt-8 text-center">
          <button 
            onClick={() => setIsLogin(!isLogin)}
            className="text-muted-foreground text-sm hover:text-white transition-colors"
          >
            {isLogin ? "Don't have an account? Sign Up" : "Already have an account? Sign In"}
          </button>
        </div>
      </div>
    </div>
  );
}

function PlaybookList({ playbooks, onSelect, onOpenSettings }: { playbooks: Playbook[], onSelect: (id: string) => void, onOpenSettings: () => void }) {
  return (
    <div className="flex flex-col h-full">
      <div className="safe-top px-6 pt-6 pb-4 flex justify-between items-center sticky top-0 bg-black/80 backdrop-blur-md z-10 border-b border-white/5">
        <h1 className="text-3xl font-bold tracking-tight">Playbooks</h1>
        <button onClick={onOpenSettings} className="p-2 text-muted-foreground hover:text-white rounded-full bg-secondary/50">
          <Settings size={20} />
        </button>
      </div>
      
      <div className="p-6 space-y-4">
        {playbooks.map(pb => (
          <button
            key={pb.id}
            onClick={() => onSelect(pb.id)}
            className="w-full text-left bg-card border border-white/5 rounded-2xl p-5 active:scale-[0.98] transition-all relative overflow-hidden group"
          >
            <div className="absolute inset-0 bg-gradient-to-br from-white/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
            <div className="flex justify-between items-start mb-3 relative z-10">
              <h3 className="font-semibold text-lg pr-4 truncate">{pb.title}</h3>
              <PhaseBadge phase={pb.phase} />
            </div>
            <div className="flex items-center text-sm text-muted-foreground relative z-10">
              <span className="w-2 h-2 rounded-full bg-primary mr-2 shadow-[0_0_10px_rgba(var(--primary),0.5)]" />
              {pb.tasks.filter(t => t.lane === "NOW" && t.status === "OPEN").length} tasks in Now
            </div>
          </button>
        ))}
        
        <button className="w-full border border-dashed border-white/20 rounded-2xl p-5 text-muted-foreground hover:text-white hover:border-white/40 transition-all font-medium flex items-center justify-center gap-2">
          <PlusCircle size={20} />
          New Playbook
        </button>
      </div>
    </div>
  );
}

function PhaseBadge({ phase }: { phase: Playbook["phase"] }) {
  const colors = {
    PROOF: "bg-blue-500/10 text-blue-400 border-blue-500/20",
    STRUCTURE: "bg-purple-500/10 text-purple-400 border-purple-500/20",
    REPEATABILITY: "bg-orange-500/10 text-orange-400 border-orange-500/20",
    GROWTH: "bg-green-500/10 text-green-400 border-green-500/20",
  };
  
  return (
    <span className={cn("text-[10px] font-bold px-2 py-1 rounded-full border tracking-wider", colors[phase])}>
      {phase}
    </span>
  );
}

function EmptyNowState({ onGoToPlaybooks }: { onGoToPlaybooks: () => void }) {
  return (
    <div className="h-full flex flex-col items-center justify-center p-8 text-center">
      <div className="w-20 h-20 rounded-full bg-secondary/50 flex items-center justify-center mb-6 border border-white/10">
        <Layers className="text-muted-foreground" size={32} />
      </div>
      <h2 className="text-xl font-bold mb-2">No Active Playbook</h2>
      <p className="text-muted-foreground mb-8">Select a playbook to view your execution lanes.</p>
      <button 
        onClick={onGoToPlaybooks}
        className="bg-white text-black font-semibold px-6 py-3 rounded-full active:scale-95 transition-all"
      >
        Go to Playbooks
      </button>
    </div>
  );
}