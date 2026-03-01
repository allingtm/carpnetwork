import { supabaseAdmin } from "./supabase-admin.ts";

export async function getUser(
  req: Request,
): Promise<{ id: string; email: string }> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    throw new AuthError("Missing or invalid authorization header");
  }
  const token = authHeader.replace("Bearer ", "");
  const {
    data: { user },
    error,
  } = await supabaseAdmin.auth.getUser(token);
  if (error || !user) {
    throw new AuthError("Invalid token");
  }
  return { id: user.id, email: user.email ?? "" };
}

export async function requireGroupAdmin(
  userId: string,
  groupId: string,
): Promise<void> {
  const { data, error } = await supabaseAdmin
    .from("group_memberships")
    .select("role")
    .eq("group_id", groupId)
    .eq("user_id", userId)
    .single();
  if (error || !data || data.role !== "admin") {
    throw new ForbiddenError("Not an admin of this group");
  }
}

export class AuthError extends Error {
  constructor(message: string) {
    super(message);
  }
}

export class ForbiddenError extends Error {
  constructor(message: string) {
    super(message);
  }
}
