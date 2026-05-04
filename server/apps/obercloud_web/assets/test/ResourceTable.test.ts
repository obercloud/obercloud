import { mount } from '@vue/test-utils'
import { describe, it, expect } from 'vitest'
import ResourceTable from '../js/vue/ResourceTable.vue'

const columns = [
  { key: 'name', label: 'Name' },
  { key: 'slug', label: 'Slug' }
]

describe('ResourceTable', () => {
  it('renders the column headers', () => {
    const w = mount(ResourceTable, { props: { columns, rows: [] } })
    const ths = w.findAll('th')
    expect(ths.map((t) => t.text())).toEqual(['Name', 'Slug'])
  })

  it('renders one row per item', () => {
    const rows = [
      { name: 'Acme', slug: 'acme' },
      { name: 'Initech', slug: 'initech' }
    ]
    const w = mount(ResourceTable, { props: { columns, rows } })

    const dataRows = w.findAll('tbody tr')
    expect(dataRows).toHaveLength(2)
    expect(dataRows[0].text()).toContain('Acme')
    expect(dataRows[0].text()).toContain('acme')
    expect(dataRows[1].text()).toContain('Initech')
  })

  it('shows an empty-state row when rows is empty', () => {
    const w = mount(ResourceTable, { props: { columns, rows: [] } })
    expect(w.text()).toContain('No rows.')
  })
})
