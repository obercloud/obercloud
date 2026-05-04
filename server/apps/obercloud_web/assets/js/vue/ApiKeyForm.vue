<script setup lang="ts">
import { ref } from 'vue'

const props = defineProps<{
  roles: string[]
}>()

const emit = defineEmits<{
  submit: [payload: { name: string; role: string; expiresAt: string | null }]
}>()

const name = ref('')
const role = ref(props.roles[0] ?? '')
const expiresAt = ref('')

function onSubmit(e: Event) {
  e.preventDefault()
  emit('submit', {
    name: name.value,
    role: role.value,
    expiresAt: expiresAt.value === '' ? null : expiresAt.value
  })
}
</script>

<template>
  <form class="space-y-3" @submit="onSubmit">
    <div>
      <label class="block text-sm">Name</label>
      <input v-model="name" type="text" class="border rounded w-full px-2 py-1" required />
    </div>
    <div>
      <label class="block text-sm">Role</label>
      <select v-model="role" class="border rounded w-full px-2 py-1">
        <option v-for="r in props.roles" :key="r" :value="r">{{ r }}</option>
      </select>
    </div>
    <div>
      <label class="block text-sm">Expires (optional)</label>
      <input v-model="expiresAt" type="datetime-local" class="border rounded w-full px-2 py-1" />
    </div>
    <button type="submit" class="bg-blue-600 text-white px-3 py-1 rounded">
      Create key
    </button>
  </form>
</template>
