extends RefCounted

const DOOR_APPROACH := Vector2(-2,2.5)
const ENTRY := Vector3(0,.04,3.14)
const HALL := Vector3(0,.04,.28)
const READING_SPOT := Vector3(-.95,.04,-1.52)
const READ_SECONDS := 18.0
const LOCAL_EDITION := "read_provence_edition"
const LOCAL_PATH := "user://books/provence-edition.json"
static var books: Dictionary = {}

const BOOKS := {
	"read_woodland": {
		"title":"《林间小路笔记》",
		"pages":[
			"一条好走的小路，总会给老树留一点地方。铺石子之前，先绕着树走一圈，看看根在哪里露出地面。遇到隆起的根，可以让小路拐一个温和的弯。",
			"挑长凳的位置时，可以在空地上坐一小会儿。看看午后的树影会移到哪里，也听听附近有什么声音。把凳面朝向自己愿意多看一会儿的地方。"
		]
	},
	"read_garden": {
		"title":"《四季小花园》",
		"pages":[
			"新播的花种需要一点耐心。先看看表土的颜色，手指碰上去还带着湿气，就再等一等。把水慢慢浇在盆边，可以让它自己渗到根旁。",
			"花谢以后，可以把干花摘下来，看看里面有没有成熟的种子。把干燥的种子装进小纸袋，写下花的颜色。来年播种时，纸袋会提醒你这盆花从哪里来。"
		]
	},
	"read_night": {"title":"《小院夜话》","pages":[
		"入夜后，窗下的灯先照亮台阶，再照亮路过的小动物。每晚留一点安静的时间，记下白天最想记住的事。",
		"写日记可以从一个细节开始。今天听到的是雨声，还是一只小兔踏上木斜坡的声音？"]},
	"read_workshop": {"title":"《木作入门》","pages":[
		"动手之前，先画出物件的正面和侧面。把最常摸到的地方画出来，想想边角要怎样磨圆。",
		"木头有自己的纹理。做个小画框时，可以顺着纹理选四条木料，给画纸留一圈安静的边。"]},
	"read_rabbit": {"title":"《兔子邻居》","pages":[
		"兔子常在熟悉的地方停下来听一听。给它留一条通畅的小路，它就能自己决定去哪里。",
		"水碗旁边总有些掉下来的草。添水时顺手收拾好，观察一会儿就知道它最喜欢哪个角落。"]},
	"read_provence_guide": {
		"title":"《普罗旺斯的一年》导读",
		"pages":[
			"原著作者彼得·梅尔。这本导读有六篇阅读随笔，陪你慢慢想一想那座法国南部的乡间小屋。",
			"一月｜新家。作者和妻子搬入吕贝龙一座老石屋。想象刚搬进一个陌生地方时，你会先收拾哪一处，让自己觉得已经到家？",
			"冬风｜天气是生活的一部分。出版社的介绍提到寒冷的密史脱拉风。给自家设计一处避风角，你会先观察风常从哪边来？",
			"春天｜看见细处。留一页给从窗边看到的变化。可以是一朵新开的花、一块刚翻的土，或者德雷克走过草地的脚印。",
			"餐桌｜书里写到了普罗旺斯的地方饮食。挑一样院子里种出来的食材，想出一道愿意与邻居分享的菜。",
			"夏日｜画一张树荫地图。早上和傍晚的树影方向不同。如果要选露营地，可以分别去看两次，把舒服的位置画下来。",
			"年末｜回望。选出过去几个季节里最想留住的一幕。它可以成为下一章故事的一小段，也可以只写在自己的日记里。"
		]
	}
}

static func load_local() -> void:
	books = BOOKS.duplicate()
	if not FileAccess.file_exists(LOCAL_PATH): return
	var edition = JSON.parse_string(FileAccess.get_file_as_string(LOCAL_PATH))
	if not edition is Array or edition.is_empty() or edition.size()>2048: return
	for page in edition:
		if not page is String or page.is_empty() or page.length()>5000: return
	books[LOCAL_EDITION] = {"title":"《普罗旺斯的一年》（彼得·梅尔，英文原著）","pages":edition}

static func catalog() -> Dictionary:
	return BOOKS if books.is_empty() else books

static func available(pages: Dictionary) -> Array:
	var titles := catalog()
	return titles.keys().filter(func(id): return int(pages.get(id,0))<titles[id].pages.size())

static func recall(pages: Dictionary) -> Array:
	var read := []
	var titles := catalog()
	for id in titles:
		var book: Dictionary = titles[id]
		var count := int(pages.get(id,0))
		if count>0:
			read.append({"title":book.title,"pages_read":count,"pages":book.pages.slice(maxi(0,count-1) if id==LOCAL_EDITION else 0,count)})
	return read

static func valid(pages: Variant) -> bool:
	if not pages is Dictionary: return false
	for id in pages:
		if not BOOKS.has(id) and id!=LOCAL_EDITION: return false
		var count = pages[id]
		if not (count is int or count is float) or count!=floor(count) or count<1 or count>(2048 if id==LOCAL_EDITION else BOOKS[id].pages.size()): return false
	return true
