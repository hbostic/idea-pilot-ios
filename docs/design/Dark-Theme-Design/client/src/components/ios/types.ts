export type Task = {
  id: string;
  title: string;
  detail?: string;
  lane: "NOW" | "NEXT" | "LATER";
  estimatedMinutes: number;
  status: "OPEN" | "DONE" | "CANCELED";
  orderIndex: number;
  completedAt?: Date;
};

export type Playbook = {
  id: string;
  title: string;
  description?: string;
  phase: "PROOF" | "STRUCTURE" | "REPEATABILITY" | "GROWTH";
  tasks: Task[];
};

export const MOCK_PLAYBOOKS: Playbook[] = [
  {
    id: "1",
    title: "Launch MVP",
    phase: "PROOF",
    tasks: [
      { id: "t1", title: "Finalize auth flow", lane: "NOW", estimatedMinutes: 60, status: "OPEN", orderIndex: 0 },
      { id: "t2", title: "Setup database schema", lane: "NOW", estimatedMinutes: 90, status: "OPEN", orderIndex: 1 },
      { id: "t3", title: "Write copy for landing page", lane: "NEXT", estimatedMinutes: 45, status: "OPEN", orderIndex: 0 },
      { id: "t4", title: "Design marketing assets", lane: "LATER", estimatedMinutes: 120, status: "OPEN", orderIndex: 0 },
    ],
  },
  {
    id: "2",
    title: "Q3 Marketing Push",
    phase: "GROWTH",
    tasks: [
      { id: "t5", title: "Review ad spend", lane: "NOW", estimatedMinutes: 30, status: "OPEN", orderIndex: 0 },
    ],
  }
];
