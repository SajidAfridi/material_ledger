import { handlePush } from "./handler.ts";

Deno.serve((request) => handlePush(request));
