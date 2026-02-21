import { useState } from "react";
import { MoreHorizontal, Plus, Check, GripVertical } from "lucide-react";
import { Playbook, Task } from "./types";
import { cn } from "./Core";
import { TaskDetailSheet } from "./TaskDetailSheet";
import { AnimatePresence, motion } from "framer-motion";

export function PlaybookHome({ 
  playbook, 
  onUpdate, 
  onOpenSections, 
  onOpenWeeklyPlan 
}: { 
  playbook: Playbook;
  onUpdate: (pb: Playbook) => void;
  onOpenSections: () => void;
  onOpenWeeklyPlan: () => void;
}) {
  const [lane, setLane] = useState<"NOW" | "NEXT" | "LATER">("NOW");
  const [selectedTask, setSelectedTask] = useState<Task | null>(null);

  const tasksInLane = playbook.tasks.filter(t => t.lane === lane && t.status === "OPEN");

  const completeTask = (taskId: string) => {
    onUpdate({
      ...playbook,
      tasks: playbook.tasks.map(t => 
        t.id === taskId ? { ...t, status: "DONE", completedAt: new Date() } : t
      )
    });
  };

  const updateTask = (updatedTask: Task) => {
    onUpdate({
      ...playbook,
      tasks: playbook.tasks.map(t => 
        t.id === updatedTask.id ? updatedTask : t
      )
    });
  };

  return (
    <div className="flex flex-col h-full bg-black relative">
      <div className="safe-top px-4 pt-4 pb-2 sticky top-0 bg-black/80 backdrop-blur-md z-10">
        <div className="flex justify-between items-center mb-4">
          <h1 className="text-2xl font-bold tracking-tight truncate pr-4">{playbook.title}</h1>
          <button className="p-2 text-muted-foreground hover:text-white rounded-full">
            <MoreHorizontal size={24} />
          </button>
        </div>
        
        {/* Segmented Control */}
        <div className="flex bg-secondary/50 p-1 rounded-xl relative">
          {(["NOW", "NEXT", "LATER"] as const).map(l => (
            <button
              key={l}
              onClick={() => setLane(l)}
              className={cn(
                "flex-1 py-1.5 text-sm font-semibold rounded-lg transition-all relative z-10",
                lane === l ? "text-white" : "text-muted-foreground hover:text-white/80"
              )}
            >
              {lane === l && (
                <motion.div
                  layoutId="active-lane"
                  className="absolute inset-0 bg-card rounded-lg shadow-sm border border-white/5"
                  transition={{ type: "spring", bounce: 0.2, duration: 0.6 }}
                />
              )}
              <span className="relative z-10 flex items-center justify-center gap-1.5">
                {l}
                <span className={cn(
                  "text-[10px] px-1.5 py-0.5 rounded-full bg-black/40",
                  lane === l ? "text-primary border border-primary/20" : "text-muted-foreground"
                )}>
                  {playbook.tasks.filter(t => t.lane === l && t.status === "OPEN").length}
                </span>
              </span>
            </button>
          ))}
        </div>
      </div>

      <div className="p-4 space-y-3 pb-32">
        <AnimatePresence mode="popLayout">
          {tasksInLane.length === 0 ? (
            <motion.div 
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              className="text-center py-12 px-4"
            >
              <p className="text-muted-foreground">
                {lane === "NOW" && "Plan your week to move tasks here."}
                {lane === "NEXT" && "Tasks you'll tackle soon appear here."}
                {lane === "LATER" && "Capture ideas to build your backlog."}
              </p>
            </motion.div>
          ) : (
            tasksInLane.map((task) => (
              <motion.div
                layout
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, x: -50, scale: 0.95 }}
                key={task.id}
                className="bg-card border border-white/5 rounded-2xl p-4 flex items-start gap-3 active:scale-[0.98] transition-all group"
                onClick={() => setSelectedTask(task)}
              >
                {lane !== "LATER" && (
                  <button 
                    onClick={(e) => { e.stopPropagation(); completeTask(task.id); }}
                    className="mt-0.5 flex-shrink-0 w-6 h-6 rounded-full border border-white/20 flex items-center justify-center text-transparent hover:border-primary hover:text-primary transition-colors focus:outline-none"
                  >
                    <Check size={14} />
                  </button>
                )}
                
                <div className="flex-1 min-w-0">
                  <p className="text-base font-medium leading-snug line-clamp-2">{task.title}</p>
                </div>
                
                <div className="flex flex-col items-end gap-2 flex-shrink-0">
                  <span className="text-xs font-semibold bg-secondary text-muted-foreground px-2 py-1 rounded-md">
                    {task.estimatedMinutes}m
                  </span>
                  <GripVertical size={16} className="text-muted-foreground/30 group-hover:text-muted-foreground transition-colors" />
                </div>
              </motion.div>
            ))
          )}
        </AnimatePresence>

        <motion.button 
          whileTap={{ scale: 0.98 }}
          className="w-full mt-4 bg-secondary/30 border border-dashed border-white/10 rounded-2xl py-4 text-muted-foreground font-medium flex items-center justify-center gap-2 hover:bg-secondary/50 transition-colors"
        >
          <Plus size={20} />
          Add Task to {lane}
        </motion.button>
      </div>

      <TaskDetailSheet 
        task={selectedTask}
        onOpenChange={(open) => !open && setSelectedTask(null)}
        onUpdate={(t) => updateTask(t)}
        onComplete={(id) => {
          completeTask(id);
          setSelectedTask(null);
        }}
        onDelete={(id) => {
          onUpdate({
            ...playbook,
            tasks: playbook.tasks.filter(t => t.id !== id)
          });
          setSelectedTask(null);
        }}
      />
    </div>
  );
}