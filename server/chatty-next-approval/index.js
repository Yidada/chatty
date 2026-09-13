import { createAnswerer, enabled, MODE, RECEIPT } from './review.js';
import { checkReviewer } from './check.js';

export const name = 'chatty-next-approval';
export const inject = ['commands', 'llm', 'permissionPresets'];

export function apply(ctx, config = {}) {
  ctx.commands.register({
    name: 'chatty-review',
    description: 'Enable Chatty Next automatic permission review for this session',
    handler: ({ agent, rawInput }) => {
      if (rawInput.trim()) return { kind: 'error', text: 'This command accepts no permission options.' };
      // Keep execution confined. The reviewer grants only individual escalations.
      ctx.permissionPresets.set(agent.session, 'workspace-write');
      if (!enabled(agent.session)) agent.session.append('chatty/approval-mode', { mode: MODE });
      return { kind: 'success', text: RECEIPT };
    }
  });
  // Review marked sessions before the normal client answerer; others delegate untouched.
  ctx.on('approval/request', createAnswerer(ctx, config), true);
  ctx.commands.register({
    name: 'chatty-review-check',
    description: 'Check automatic review against fixed synthetic cases without executing tools',
    handler: async ({ rawInput, signal }) => rawInput.trim()
      ? { kind: 'error', text: 'This diagnostic accepts no input.' }
      : { kind: 'success', text: JSON.stringify(await checkReviewer(ctx.llm, signal)) }
  });
}
