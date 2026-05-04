import { mount } from '@vue/test-utils'
import { describe, it, expect } from 'vitest'
import ApiKeyForm from '../js/vue/ApiKeyForm.vue'

const roles = ['org:admin', 'org:member', 'org:viewer']

describe('ApiKeyForm', () => {
  it('renders one option per role', () => {
    const w = mount(ApiKeyForm, { props: { roles } })
    const options = w.findAll('option')
    expect(options).toHaveLength(3)
    expect(options.map((o) => o.text())).toEqual(roles)
  })

  it('emits submit with the form payload', async () => {
    const w = mount(ApiKeyForm, { props: { roles } })

    await w.find('input[type="text"]').setValue('CI key')
    await w.find('select').setValue('org:viewer')
    await w.find('input[type="datetime-local"]').setValue('2027-01-01T00:00')
    await w.find('form').trigger('submit')

    expect(w.emitted('submit')).toBeTruthy()
    expect(w.emitted('submit')![0]).toEqual([
      { name: 'CI key', role: 'org:viewer', expiresAt: '2027-01-01T00:00' }
    ])
  })

  it('emits expiresAt as null when blank', async () => {
    const w = mount(ApiKeyForm, { props: { roles } })

    await w.find('input[type="text"]').setValue('No expiry')
    await w.find('form').trigger('submit')

    expect(w.emitted('submit')![0]).toEqual([
      { name: 'No expiry', role: 'org:admin', expiresAt: null }
    ])
  })
})
