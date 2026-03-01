import { z } from "npm:zod@^3.23.0";

export function validate<T extends z.ZodObject<z.ZodRawShape>>(
  schema: T,
  data: unknown,
): z.infer<T> {
  const result = schema.strict().safeParse(data);
  if (!result.success) {
    throw new ValidationError(result.error.issues);
  }
  return result.data;
}

export class ValidationError extends Error {
  public issues: z.ZodIssue[];
  constructor(issues: z.ZodIssue[]) {
    super("Validation failed");
    this.issues = issues;
  }
}
