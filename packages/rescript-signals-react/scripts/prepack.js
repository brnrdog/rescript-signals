const fs = require("fs");
const file = "rescript.json";

fs.cpSync(file, file + ".bak");

const config = JSON.parse(fs.readFileSync(file, "utf8"));
config.sources = config.sources.filter((s) => s.type !== "dev");
delete config["dev-dependencies"];

fs.writeFileSync(file, JSON.stringify(config, null, 2) + "\n");
