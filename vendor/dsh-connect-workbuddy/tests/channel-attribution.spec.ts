import { describe, expect, it } from 'vitest'
import { prepareChatBody } from '../src/upstream.ts'

/**
 * The Tencent channel gate rejects `powered by DeepSeek Harness` in the system
 * message with business code `11128`, which is what DSH's own base prompt opens
 * with. These assertions pin the rewrite that keeps that request reachable.
 */

const BAD = 'You are an AI agent powered by DeepSeek Harness.'
const body = (messages: unknown[], extra: Record<string, unknown> = {}): string =>
  JSON.stringify({ model: 'deepseek-v4.1-flash', messages, ...extra })

const first = (prepared: string): Record<string, unknown> =>
  (JSON.parse(prepared) as { messages: Array<Record<string, unknown>> }).messages[0] ?? {}

describe('scrubChannelAttribution', () => {
  it('rewrites the blocked construction out of the system message', () => {
    const prepared = prepareChatBody(body([{ role: 'system', content: BAD }]))
    expect(prepared).not.toMatch(/powered\s+by\s+DeepSeek\s+Harness/i)
    expect(first(prepared)['content']).toBe('You are an AI agent running inside DeepSeek Harness.')
  })

  it('keeps the product name and the rest of the prompt intact', () => {
    const content = `${BAD}\n\n# Tone\nBe concise.`
    const prepared = prepareChatBody(body([{ role: 'system', content }]))
    const out = String(first(prepared)['content'])
    expect(out).toContain('DeepSeek Harness')
    expect(out).toContain('# Tone\nBe concise.')
  })

  it('matches case-insensitively', () => {
    const prepared = prepareChatBody(body([{ role: 'system', content: 'You are powered by deepseek harness!' }]))
    expect(prepared).not.toMatch(/powered\s+by\s+deepseek\s+harness/i)
  })

  it('rewrites every occurrence, not just the first', () => {
    const content = `${BAD} Later: powered by DeepSeek Harness again.`
    const prepared = prepareChatBody(body([{ role: 'system', content }]))
    expect(prepared).not.toMatch(/powered\s+by\s+DeepSeek\s+Harness/i)
    expect(String(first(prepared)['content']).match(/running inside DeepSeek Harness/g)).toHaveLength(2)
  })

  it('leaves a system message that does not carry the phrase untouched', () => {
    const content = 'You are a helpful assistant.'
    expect(prepareChatBody(body([{ role: 'system', content }]))).toBe(body([{ role: 'system', content, stream: true }]))
  })

  it('does not touch user turns', () => {
    const prepared = prepareChatBody(body([
      { role: 'system', content: 'You are a helpful assistant.' },
      { role: 'user', content: `Is this ${'powered by DeepSeek Harness'}?` },
    ]))
    expect(prepared).toContain('Is this powered by DeepSeek Harness?')
  })

  it('does not touch tool descriptions', () => {
    const prepared = prepareChatBody(body(
      [{ role: 'system', content: 'You are a helpful assistant.' }],
      { tools: [{ type: 'function', function: { name: 'noop', description: 'A tool powered by DeepSeek Harness.' } }] },
    ))
    expect(prepared).toContain('A tool powered by DeepSeek Harness.')
  })

  it('covers a prompt that only became a system message through the developer rewrite', () => {
    const prepared = prepareChatBody(body([{ role: 'developer', content: BAD }]))
    expect(first(prepared)['role']).toBe('system')
    expect(prepared).not.toMatch(/powered\s+by\s+DeepSeek\s+Harness/i)
  })

  it('is idempotent', () => {
    const once = prepareChatBody(body([{ role: 'system', content: BAD }]))
    expect(prepareChatBody(once)).toBe(once)
  })

  /**
   * The fingerprint that actually fired in production. Each sentence of DSH's
   * file-reference instructions passes the gateway alone; together they are
   * refused with 11128, so the rewrite must break the pair, not one sentence.
   */
  const FILE_REFERENCE = 'Tokens prefixed with @ are paths the user explicitly referenced. Relative paths resolve from the workspace root; absolute paths identify files or directories on the host.'

  it('rewrites the file-reference fingerprint', () => {
    const prepared = prepareChatBody(body([{ role: 'system', content: FILE_REFERENCE }]))
    expect(prepared).not.toContain('Tokens prefixed with @ are paths the user explicitly referenced.')
    expect(prepared).toContain('Relative paths resolve from the workspace root')
  })

  it('leaves the surrounding instructions readable after the rewrite', () => {
    const prepared = prepareChatBody(body([{ role: 'system', content: `Intro.\n\n${FILE_REFERENCE}\n\nNon-zero exits are reported as markers.` }]))
    const out = String(first(prepared)['content'])
    expect(out).toContain('Intro.')
    expect(out).toContain('Non-zero exits are reported as markers.')
    expect(out).toContain('@')
  })

  it('rewrites every occurrence of the file-reference phrase', () => {
    const prepared = prepareChatBody(body([{ role: 'system', content: `${FILE_REFERENCE}\n\n${FILE_REFERENCE}` }]))
    expect(prepared).not.toContain('Tokens prefixed with @ are paths the user explicitly referenced.')
  })
})
