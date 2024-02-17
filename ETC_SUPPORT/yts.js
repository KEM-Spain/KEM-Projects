(async function(){
	const mods = "/home/kmiller/.npm-packages/lib/node_modules"
	
	const { Command } = require(mods+'/commander');
	const app = new Command();

	app
		.description('Search and download from youTube')
		.version('1.0')
		.argument('<searchterm>', 'youtube search term')
		.option('-s, --strict', 'display only author matching searchterm')
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
		if (age === "all") {
			has_match = true
			if (msgout === false) process.stdout.write("matched on all\n")
			msgout = true
		} 
		/* ago = v.ago */
		if (v.ago.indexOf(age) >= 1) {
			if (msgout === false) process.stdout.write("matched on v.ago:"+age+"\n")
			has_match = true
			msgout = true
		} 
		v.title = v.title.replace(/\|/g, ':')
		if (has_match) {
			if (strict) {
				t_arg = searchterm.toLowerCase()
				v_arg = v.author.name.toLowerCase()
				if (v_arg.indexOf(t_arg) < 0) {
					return
				}
			}
			console.log(`${v.ago}|${v.author.name}|${v.title}|${v.url}|${v.timestamp}`)
		}
	})           
})()
