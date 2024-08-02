require('dotenv').config();
const process = require('process');
const username = process.env.WEB_USERNAME || "admin";
const password = process.env.WEB_PASSWORD || "password";
const os = require('os');
const path = require('path');
const express = require("express");
const fs = require('fs');
const app = express();
var exec = require("child_process").exec;
const auth = require("basic-auth");

const USERNAME = os.userInfo().username;
const WORKDIR = path.join('/home', USERNAME, 'domains', `${USERNAME}.serv00.net`, 'public_nodejs');
process.chdir(WORKDIR);

app.get("/", function (req, res) {
  res.type("html").send("<pre>Powered by X-for-Serv00\nAuthor: <a href='https://github.com/k0baya'>K0baya</a>" + "</pre>");
});

// 页面访问密码
app.use((req, res, next) => {
  const user = auth(req);
  if (user && user.name === username && user.pass === password) {
    return next();
  }
  res.set("WWW-Authenticate", 'Basic realm="Node"');
  return res.status(401).send();
});

app.get("/status", function (req, res) {
  let cmdStr =
    "ps aux";
  exec(cmdStr, function (err, stdout, stderr) {
    if (err) {
      res.type("html").send("<pre>命令行执行错误：\n" + err + "</pre>");
    } else {
      res.type("html").send("<pre>获取系统进程表：\n" + stdout + "</pre>");
    }
  });
});

//获取节点数据
app.get("/list", async function (req, res) {
  let cmdStr = "cat list";
  const fileExists = (path) => {
    return new Promise((resolve, reject) => {
      fs.access(path, fs.constants.F_OK, (err) => {
        resolve(!err);
      });
    });
  };

  const waitForFile = async (path, retries, interval) => {
    for (let i = 0; i < retries; i++) {
      if (await fileExists(path)) {
        return true;
      }
      await new Promise(resolve => setTimeout(resolve, interval));
    }
    return false;
  };

  const fileReady = await waitForFile('list', 30, 1000);

  if (!fileReady) {
    res.type("html").send("<pre>文件未生成</pre>");
    return;
  }

  exec(cmdStr, function (err, stdout, stderr) {
    if (err) {
      res.type("html").send("<pre>命令行执行错误：\n" + err + "</pre>");
    } else {
      res.type("html").send("<pre>节点数据：\n\n" + stdout + "</pre>");
    }
  });
});
  
function keep_web_alive() {
  exec("pgrep -laf web.js", function (err, stdout, stderr) {
    if (stdout.includes("./web.js -c ./config.json")) {
      console.log("web 正在运行");
    } else {
      exec(
        "chmod +x web.js && ./web.js -c ./config.json > /dev/null 2>&1 &",
        function (err, stdout, stderr) {
          if (err) {
            console.log("保活-调起web-命令行执行错误:" + err);
          } else {
            console.log("保活-调起web-命令行执行成功!");
          }
        }
      );
    }
  });
}
setInterval(keep_web_alive, 10 * 1000);

function keep_argo_alive() {
  exec("pgrep -laf cloudflared", function (err, stdout, stderr) {
    if (stdout.includes("./cloudflared tunnel")) {
      console.log("Argo 正在运行");
    } else {
      exec("chmod +x argo.sh && bash argo.sh 2>&1 &", function (err, stdout, stderr) {
        if (err) {
          console.log("保活-调起Argo-命令行执行错误:" + err);
        } else {
          console.log("保活-调起Argo-命令行执行成功!");
        }
      });
    }
  });
}
setInterval(keep_argo_alive, 30 * 1000);

app.listen(3000, () => console.log(`Example app listening on port 3000!`));
