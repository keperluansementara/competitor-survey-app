import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import App from './App';

describe('application foundation', () => {
  it('does not show placeholder metrics when Supabase is not configured', () => {
    const html = renderToStaticMarkup(<App />);

    expect(html).toContain('Hubungkan Supabase development');
    expect(html).toContain('.env.local');
    expect(html).not.toContain('Target outlet');
  });
});
