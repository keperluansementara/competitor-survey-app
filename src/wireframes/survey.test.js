import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { Window } from 'happy-dom';

const html = readFileSync(new URL('./survey.html', import.meta.url), 'utf8');

function createWireframe() {
  const window = new Window({ url: 'http://localhost/' });
  window.document.write(html);
  const script = [...window.document.querySelectorAll('script')].at(-1);
  window.eval(script.textContent);
  return window;
}

describe('survey wireframe navigation', () => {
  it('opens the product form from the outlet step', () => {
    const window = createWireframe();

    window.document.querySelector('[data-panel="0"] [data-next]').click();

    expect(window.document.querySelector('[data-panel="0"]').hidden).toBe(true);
    expect(window.document.querySelector('[data-panel="1"]').hidden).toBe(false);
    expect(window.document.querySelector('#product').labels[0].textContent).toContain('SKU');
    window.happyDOM.abort();
  });

  it('lets the user open a step from the progress bar', () => {
    const window = createWireframe();

    window.document.querySelector('[data-step-link="1"]').click();

    expect(window.document.querySelector('[data-panel="1"]').hidden).toBe(false);
    expect(window.document.querySelector('[data-step-link="1"]').getAttribute('aria-current')).toBe('step');
    window.happyDOM.abort();
  });

  it('moves through evidence and review, then shows a demo completion state', () => {
    const window = createWireframe();
    const next = () => window.document.querySelector(`[data-panel="${window.document.querySelector('[data-panel]:not([hidden])').dataset.panel}"] [data-next]`).click();

    next();
    next();
    next();
    expect(window.document.querySelector('[data-panel="3"]').hidden).toBe(false);
    expect(window.document.querySelector('#reviewProduct').textContent).toContain('Biskuit Gery');
    window.document.querySelector('#submitSurvey').click();
    expect(window.document.querySelector('#syncState').textContent).toContain('Demo selesai');
    expect(window.document.querySelector('#message').textContent).toContain('server mengonfirmasi');
    window.happyDOM.abort();
  });
});
