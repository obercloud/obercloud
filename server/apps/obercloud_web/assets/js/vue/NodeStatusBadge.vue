<script setup lang="ts">
defineProps<{
  status: 'provisioning' | 'ready' | 'degraded' | 'decommissioned'
}>()

const colors = {
  provisioning: 'bg-yellow-200 text-yellow-800',
  ready: 'bg-green-200 text-green-800',
  degraded: 'bg-orange-200 text-orange-800',
  decommissioned: 'bg-gray-200 text-gray-700'
} as const
</script>

<template>
  <span :class="['px-2 py-1 rounded text-xs', colors[status]]">{{ status }}</span>
</template>
