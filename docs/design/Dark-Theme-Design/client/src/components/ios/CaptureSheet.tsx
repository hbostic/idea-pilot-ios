import { useState, useEffect } from "react";
import { Drawer } from "vaul";
import { Task } from "./types";
import { cn } from "./Core";

export function CaptureSheet({ 
  isOpen, 
  onOpenChange,
  playbookId,
  onAdd
}: { 
  isOpen: boolean; 
  onOpenChange: (open: boolean) => void;
  playbookId: string | null;
  onAdd: (task: Task) => void;
}) {
  const [title, setTitle] = useState("");
  const [lane, setLane] = useState<"NOW" | "NEXT" | "LATER">("LATER");
  const [estimate, setEstimate] = useState<number>(60);

  // Reset state when opened
  useEffect(() => {
    if (isOpen) {
      setTitle("");
      setLane("LATER");
      setEstimate(60);
    }
  }, [isOpen]);

  const handleAdd = () => {
    if (!title.trim() || !playbookId) return;
    
    onAdd({
      id: Math.random().toString(36).substr(2, 9),
      title: title.trim(),
      lane,
      estimatedMinutes: estimate,
      status: "OPEN"
    });
    
    setTitle(""); // Allow rapid capture
  };

  return (
    <Drawer.Root open={isOpen} onOpenChange={onOpenChange}>
      <Drawer.Portal>
        <Drawer.Overlay className="fixed inset-0 bg-black/60 z-50 backdrop-blur-sm" />
        <Drawer.Content className="bg-card flex flex-col rounded-t-3xl mt-24 fixed bottom-0 left-0 right-0 max-w-md mx-auto z-50 border-t border-white/10 outline-none">
          <div className="p-4 bg-card rounded-t-3xl flex-1 safe-bottom flex flex-col">
            <div className="mx-auto w-12 h-1.5 flex-shrink-0 rounded-full bg-white/20 mb-6" />
            
            <input 
              autoFocus
              type="text" 
              placeholder="What needs to happen?"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="w-full bg-transparent text-2xl font-bold text-white placeholder:text-white/20 focus:outline-none mb-8"
              onKeyDown={(e) => {
                if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) {
                  handleAdd();
                }
              }}
            />
            
            <div className="space-y-6">
              <div className="space-y-3">
                <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">Lane</label>
                <div className="flex gap-2">
                  {(["NOW", "NEXT", "LATER"] as const).map(l => (
                    <button
                      key={l}
                      onClick={() => setLane(l)}
                      className={cn(
                        "flex-1 py-2 rounded-xl text-sm font-semibold transition-all border",
                        lane === l 
                          ? "bg-white text-black border-white" 
                          : "bg-secondary/50 text-muted-foreground border-transparent hover:bg-secondary"
                      )}
                    >
                      {l}
                    </button>
                  ))}
                </div>
              </div>
              
              <div className="space-y-3">
                <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">Estimate</label>
                <div className="flex gap-2">
                  {[30, 60, 90, 120].map(mins => (
                    <button
                      key={mins}
                      onClick={() => setEstimate(mins)}
                      className={cn(
                        "flex-1 py-2 rounded-xl text-sm font-semibold transition-all border",
                        estimate === mins 
                          ? "bg-primary/20 text-primary border-primary/50" 
                          : "bg-secondary/50 text-muted-foreground border-transparent hover:bg-secondary"
                      )}
                    >
                      {mins}m
                    </button>
                  ))}
                </div>
              </div>
            </div>
            
            <div className="mt-8 flex gap-3">
              <button 
                onClick={handleAdd}
                disabled={!title.trim() || !playbookId}
                className="flex-1 bg-primary text-white font-semibold rounded-xl py-4 active:scale-[0.98] transition-all shadow-[0_4px_20px_rgba(var(--primary),0.3)] disabled:opacity-50 disabled:shadow-none"
              >
                Add to {lane}
              </button>
            </div>
          </div>
        </Drawer.Content>
      </Drawer.Portal>
    </Drawer.Root>
  );
}