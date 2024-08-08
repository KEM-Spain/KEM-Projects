(async function(){
	const mods = "/home/kmiller/node_modules"
	
	const { Command } = require(mods+'/commander');
	const app = new Command();

	app
		.description('Search YouTube')
		.version('1.0')
		.argument('<searchterm>', 'youtube search term')
		.option('-s, --strict', 'author must match searchterm')
		.option('-a, --age <keyword>', 'all min hour day week mon year', 'all')

	app.parseAsync(process.argv);

	const searchterm = app.args[0]
	const options = app.opts()
	const age = options['age']
	const strict = options['strict'] ? 1 : false

	/*
	console.log("searchterm:"+searchterm)
	console.log("age:"+age)
	console.log("strict:"+strict)
	*/

	const yts = require(mods+'/yt-search')
	const r = await yts(searchterm)
	const videos = r.videos.slice(0,50)
	
	/*
	let str = JSON.stringify(videos, null, 2)
	process.stderr.write(str)
	*/

	msgout = false
	videos.forEach(function (v) {
		has_match = false
		if (age === "all") { /* any age is default */
			has_match = true
			if (msgout === false) {
				console.log("matched on all")
				msgout = true
			}
		} else {
			if (v.ago.indexOf(age) >= 0) { /* age was specified */
				has_match = true
				console.log("matched on age (non-strict)")
				msgout = true
			}
		} 
		v.title = v.title.replace(/\|/g, ':') /* titles contain pipe separators */
		if (has_match) {
			if (strict) { /* searchterm must be in title */
				t_arg = searchterm.toLowerCase()
				v_arg = v.author.name.toLowerCase()
				v_arg = v_arg.replace(/ /g, '')
				if (v_arg.indexOf(t_arg) >= 0) { /* searchterm is in title */
					if (msgout === false) {
						console.log("matched strict")
						msgout = true
					}
				} else {
					console.log("rejected strict:"+v_arg+" != "+t_arg) /* searchterm NOT in title */
					return	
				}
			}
			console.log(`${v.ago}|${v.author.name}|${v.title}|${v.url}|${v.timestamp}`)
		}
	})           
})()
