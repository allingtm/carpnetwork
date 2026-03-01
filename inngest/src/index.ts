import { serve } from "inngest/express";
import { inngest } from "./client";
import { photoProcess } from "./functions/photo-process";

// Register all Inngest functions
export const inngestHandler = serve({
  client: inngest,
  functions: [photoProcess],
});

// Export for use with Express or similar HTTP server
export { inngest, photoProcess };
