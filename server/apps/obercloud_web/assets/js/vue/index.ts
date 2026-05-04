// Component registry — when a future task wires LiveVue's getHooks() into
// app.js, these will become the components addressable from HEEx via
// <.vue v-component="NodeStatusBadge" v-props={...} />.
import OrgSwitcher from './OrgSwitcher.vue'
import NodeStatusBadge from './NodeStatusBadge.vue'
import ApiKeyForm from './ApiKeyForm.vue'
import ResourceTable from './ResourceTable.vue'

export default { OrgSwitcher, NodeStatusBadge, ApiKeyForm, ResourceTable }
