<script setup lang="ts">
interface Org {
  id: string
  name: string
}

const props = defineProps<{
  orgs: Org[]
  activeOrgId: string
}>()

const emit = defineEmits<{
  change: [orgId: string]
}>()

function onChange(e: Event) {
  const target = e.target as HTMLSelectElement
  emit('change', target.value)
}
</script>

<template>
  <select
    class="border rounded px-2 py-1 text-sm"
    :value="props.activeOrgId"
    @change="onChange"
  >
    <option v-for="org in props.orgs" :key="org.id" :value="org.id">
      {{ org.name }}
    </option>
  </select>
</template>
