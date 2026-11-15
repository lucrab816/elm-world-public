extends RefCounted
# Fixed, plain-language recovery guidance; no remote text, credentials or actions.
const AUTH_HELP := "https://learn.chatgpt.com/docs/auth"
static func guidance(code: String) -> String:
	return {
		"cli_missing":"本机接入工具或配置不可用。请使用本机最新版；若仍不可用，先用本地模拟，并在聊天帮助中查看接入说明。",
		"subscription_login_required":"本机接入工具尚未使用ChatGPT账号登录。请按官方登录说明完成登录，再回来手动发送。",
		"login_expired":"本机接入工具的登录已失效。请按官方说明重新登录，再回来手动发送；刷新本机状态不会验证登录。",
		"usage_limit":"订阅额度不足。请等账户额度恢复后再手动发送；小世界无法确定账户的恢复时间。",
		"rate_limit":"服务暂时限制请求。请稍后再手动发送，并遵守面板上的本地冷却时间。",
		"timeout":"这次回复超时，已停止等待。可以把原话放回输入框，等本地冷却结束后手动再发。",
		"network_error":"这次连接没有完成。请检查网络，恢复后再手动发送；本次尝试仍计入本地次数。",
		"cancelled":"请求已取消。可以继续本地生活，也可以放回原话，等冷却结束后手动发送。",
		"cooldown":"两次真实请求至少间隔2分钟。请等上方倒计时结束；草稿会保留。",
		"local_limit":"小世界本地5小时内的尝试已用完。请等上方显示恢复次数后再发，重启不会清零。",
		"budget_unreadable":"用量记录暂不可读，真实发送已暂停。请先用本地模拟，保留记录供排查，不要删除或重置次数。",
		"busy":"上一请求仍在收尾。请稍等，收尾完成后再手动操作；不必重复点击。",
		"host_permission":"本机接入没有获得所需的运行权限。请先用本地模拟，保留此提示交给维护者检查。",
		"invalid_decision":"这次回复格式无法使用。没有执行任何世界动作；可以放回原话，等冷却结束后手动再发。",
		"unexpected_tool_activity":"这次回复包含聊天范围外的操作，已拒绝接收。小世界继续生活，请先用本地模拟。"
	}.get(code,"这次没有取得可用回复。可以放回原话，等冷却结束后手动再发；不会自动重试或改用付费API。")
