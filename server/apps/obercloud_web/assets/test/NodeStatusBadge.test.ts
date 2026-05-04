import { mount } from '@vue/test-utils'
import { describe, it, expect } from 'vitest'
import NodeStatusBadge from '../js/vue/NodeStatusBadge.vue'

describe('NodeStatusBadge', () => {
  it('renders status text', () => {
    const w = mount(NodeStatusBadge, { props: { status: 'ready' } })
    expect(w.text()).toBe('ready')
  })

  it('applies the green class for ready', () => {
    const w = mount(NodeStatusBadge, { props: { status: 'ready' } })
    expect(w.classes()).toContain('bg-green-200')
  })

  it('applies the yellow class for provisioning', () => {
    const w = mount(NodeStatusBadge, { props: { status: 'provisioning' } })
    expect(w.classes()).toContain('bg-yellow-200')
  })

  it('applies the orange class for degraded', () => {
    const w = mount(NodeStatusBadge, { props: { status: 'degraded' } })
    expect(w.classes()).toContain('bg-orange-200')
  })

  it('applies the gray class for decommissioned', () => {
    const w = mount(NodeStatusBadge, { props: { status: 'decommissioned' } })
    expect(w.classes()).toContain('bg-gray-200')
  })
})
