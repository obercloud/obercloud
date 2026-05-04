import { mount } from '@vue/test-utils'
import { describe, it, expect } from 'vitest'
import OrgSwitcher from '../js/vue/OrgSwitcher.vue'

const orgs = [
  { id: 'a-id', name: 'Org A' },
  { id: 'b-id', name: 'Org B' }
]

describe('OrgSwitcher', () => {
  it('renders one option per org', () => {
    const w = mount(OrgSwitcher, { props: { orgs, activeOrgId: 'a-id' } })
    const options = w.findAll('option')
    expect(options).toHaveLength(2)
    expect(options[0].text()).toBe('Org A')
    expect(options[1].text()).toBe('Org B')
  })

  it('selects the activeOrgId option', () => {
    const w = mount(OrgSwitcher, { props: { orgs, activeOrgId: 'b-id' } })
    const select = w.find('select').element as HTMLSelectElement
    expect(select.value).toBe('b-id')
  })

  it('emits change with the new org id', async () => {
    const w = mount(OrgSwitcher, { props: { orgs, activeOrgId: 'a-id' } })
    await w.find('select').setValue('b-id')

    expect(w.emitted('change')).toBeTruthy()
    expect(w.emitted('change')![0]).toEqual(['b-id'])
  })
})
