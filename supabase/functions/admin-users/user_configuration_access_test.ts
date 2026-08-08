import { assertEquals } from 'jsr:@std/assert@1'

import { canConfigureUsers } from './user_configuration_access.ts'

Deno.test('only Admin and Senior Mechanical Engineer configure users', () => {
  assertEquals(canConfigureUsers('admin'), true)
  assertEquals(canConfigureUsers('senior_mechanical_engineer'), true)
  assertEquals(canConfigureUsers('project_manager'), false)
  assertEquals(canConfigureUsers('project_engineer'), false)
  assertEquals(canConfigureUsers('procurement'), false)
  assertEquals(canConfigureUsers(null), false)
})
