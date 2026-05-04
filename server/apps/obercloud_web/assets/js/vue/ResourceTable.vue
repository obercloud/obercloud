<script setup lang="ts" generic="Row extends Record<string, unknown>">
interface Column {
  key: string
  label: string
}

defineProps<{
  columns: Column[]
  rows: Row[]
}>()
</script>

<template>
  <table class="w-full border">
    <thead>
      <tr class="border-b bg-gray-50">
        <th v-for="col in columns" :key="col.key" class="text-left p-2">
          {{ col.label }}
        </th>
      </tr>
    </thead>
    <tbody>
      <tr v-for="(row, i) in rows" :key="i" class="border-b">
        <td v-for="col in columns" :key="col.key" class="p-2">
          {{ row[col.key] }}
        </td>
      </tr>
      <tr v-if="rows.length === 0">
        <td :colspan="columns.length" class="p-4 text-center text-gray-500">
          No rows.
        </td>
      </tr>
    </tbody>
  </table>
</template>
