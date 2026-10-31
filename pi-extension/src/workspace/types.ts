/** Shared, SDK-independent contract for opening an agent in a host folder. */
export type WorkspaceAgent = "pi" | "codex" | "deepseek";

export interface WorkspaceAgentInfo {
  id: WorkspaceAgent;
  name: string;
  available: boolean;
  description?: string;
  reason?: string;
}

export interface WorkspaceDirectory {
  path: string;
  parent: string | null;
  home: string;
  roots: string[];
  directories: Array<{ name: string; path: string }>;
  agents: WorkspaceAgentInfo[];
  truncated: boolean;
}

export interface OpenedWorkspace {
  id: string;
  cwd: string;
  name: string;
  agent: WorkspaceAgent;
  room_id: string;
}

export type WorkspaceRequest =
  | { type: "workspace_browse"; id: string; path?: string; show_hidden?: boolean }
  | { type: "workspace_open"; id: string; path: string; agent: WorkspaceAgent };

export type WorkspaceReply =
  | { type: "workspace_listing"; in_reply_to: string; directory: WorkspaceDirectory }
  | { type: "workspace_opened"; in_reply_to: string; workspace: OpenedWorkspace }
  | { type: "workspace_error"; in_reply_to: string; error: string };
