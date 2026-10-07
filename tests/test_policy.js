const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
let rule;
const source = fs.readFileSync(path.join(__dirname, "../polkit/easytier.rules.in"), "utf8");
vm.runInNewContext(source.replace("__USERNAME_JSON__", JSON.stringify("alice")), {
  polkit: { Result: { YES: "yes" }, addRule: fn => { rule = fn; } }
});
function check(user, unit, verb, id = "org.freedesktop.systemd1.manage-units") {
  return rule({ id, lookup: key => ({ unit, verb })[key] }, { user });
}
for (const verb of ["start", "stop", "restart"]) assert.equal(check("alice", "easytier.service", verb), "yes");
for (const user of ["guest", "other"]) assert.equal(check(user, "easytier.service", "stop"), undefined);
for (const unit of ["sshd.service", "NetworkManager.service", "easytier-other.service"]) assert.equal(check("alice", unit, "stop"), undefined);
for (const verb of ["kill", "reload", "enable", "disable"]) assert.equal(check("alice", "easytier.service", verb), undefined);
assert.equal(check("alice", "easytier.service", "start", "org.freedesktop.systemd1.manage-unit-files"), undefined);
console.log("Policy scope tests passed");
