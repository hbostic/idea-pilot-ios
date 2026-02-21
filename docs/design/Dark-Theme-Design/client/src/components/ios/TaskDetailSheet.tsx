import { useState, useEffect } from "react";
import { Drawer } from "vaul";
import { Task } from "./types";
import { cn } from "./Core";

export function TaskDetailSheet({ 
  task, 
  onOpenChange,
  onUpdate,
  onComplete,
  onDelete
}: { 
  task: Task | null;
  onOpenChange: (open: boolean) => void;
  onUpdate: (task: Task) => void;
  onComplete: (id: string) => void;
  onDelete: (id: string) => void;
}) {
  const [editedTask, setEditedTask] = useState<Task | null>(null);

  useEffect(() => {
    if (task) setEditedTask({ ...task });
  }, [task]);

  if (!editedTask) return null;

  return (
    <Drawer.Root open={!!task} onOpenChange={onOpenChange}>
      <Drawer.Portal>
        <Drawer.Overlay className="fixed inset-0 bg-black/60 z-50 backdrop-blur-sm" />
        <Drawer.Content className="bg-card flex flex-col rounded-t-3xl mt-24 fixed bottom-0 left-0 right-0 max-w-md mx-auto z-50 border-t border-white/10 outline-none max-h-[85vh]">
          <div className="p-4 bg-card rounded-t-3xl flex-1 safe-bottom flex flex-col overflow-y-auto no-scrollbar">
            <div className="mx-auto w-12 h-1.5 flex-shrink-0 rounded-full bg-white/20 mb-6" />
            
            <div className="flex items-center gap-2 mb-4">
              <span className={cn(
                "text-xs font-bold px-2.5 py-1 rounded-full border",
                editedTask.status === "DONE" 
                  ? "bg-green-500/20 text-green-400 border-green-500/30" 
                  : "bg-blue-500/20 text-blue-400 border-blue-500/30"
              )}>
                {editedTask.status}
              </span>
            </div>

            <textarea 
              value={editedTask.title}
              onChange={(e) => {
                const newTask = { ...editedTask, title: e.target.value };
                setEditedTask(newTask);
                onUpdate(newTask);
              }}
              className="w-full bg-transparent text-2xl font-bold text-white placeholder:text-white/20 focus:outline-none mb-6 resize-none min-h-[80px]"
              placeholder="Task Title"
            />
            
            <div className="space-y-6 flex-1">
              <div className="space-y-3">
                <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">Lane</label>
                <div className="flex gap-2">
                  {(["NOW", "NEXT", "LATER"] as const).map(l => (
                    <button
                      key={l}
                      onClick={() => {
                        const newTask = { ...editedTask, lane: l };
                        setEditedTask(newTask);
                        onUpdate(newTask);
                      }}
                      className={cn(
                        "flex-1 py-2 rounded-xl text-sm font-semibold transition-all border",
                        editedTask.lane === l 
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
                <div className="flex flex-wrap gap-2">
                  {[30, 60, 90, 120, 180].map(mins => (
                    <button
                      key={mins}
                      onClick={() => {
                        const newTask = { ...editedTask, estimatedMinutes: mins };
                        setEditedTask(newTask);
                        onUpdate(newTask);
                      }}
                      className={cn(
                        "flex-1 py-2 rounded-xl text-sm font-semibold transition-all border min-w-[60px]",
                        editedTask.estimatedMinutes === mins 
                          ? "bg-primary/20 text-primary border-primary/50" 
                          : "bg-secondary/50 text-muted-foreground border-transparent hover:bg-secondary"
                      )}
                    >
                      {mins}m
                    </button>
                  ))}
                </div>
                {editedTask.estimatedMinutes > 180 && (
                  <p className="text-xs text-orange-400 mt-1">Tasks over 3 hours should be broken down. Can you split this?</p>
                )}
              </div>

              <div className="space-y-3">
                <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">Notes</label>
                <textarea 
                  value={editedTask.notes || ""}
                  onChange={(e) => {
                    const newTask = { ...editedTask, notes: e.target.value };
                    setEditedTask(newTask);
                    onUpdate(newTask);
                  }}
                  className="w-full bg-secondary/30 border border-white/5 rounded-xl p-4 text-sm text-white placeholder:text-muted-foreground focus:outline-none focus:border-white/20 min-h-[120px] resize-none"
                  placeholder="Add notes or details..."
                />
              </div>
            </div>
            
            <div className="mt-8 space-y-3 pb-4">
              {editedTask.status === "OPEN" && (
                <button 
                  onClick={() => onComplete(editedTask.id)}
                  className="w-full bg-accent text-accent-foreground font-semibold rounded-xl py-4 active:scale-[0.98] transition-all shadow-[0_4px_20px_rgba(var(--accent),0.3)]"
                >
                  Complete Task
                </button>
              )}
              <button 
                onClick={() => {
                  if (confirm("Delete this task? This can't be undone.")) {
                    onDelete(editedTask.id);
                  }
                }}
                className="w-full bg-transparent text-destructive font-semibold border border-destructive/20 rounded-xl py-4 active:scale-[0.98] transition-all hover:bg-destructive/10"
              >
                Delete Task
              </button>
            </div>
          </div>
        </Drawer.Content>
      </Drawer.Portal>
    </Drawer.Root>
  );
}