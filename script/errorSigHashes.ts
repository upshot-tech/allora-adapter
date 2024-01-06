import { ethers } from "ethers";
import { resolve } from "path";
import { readFile } from "fs";
import { readdir } from "fs/promises";

async function* getFiles(dir: string): AsyncGenerator<string> {
  const dirents = await readdir(dir, { withFileTypes: true });
  for (const dirent of dirents) {
    const res = resolve(dir, dirent.name);
    if (dirent.isDirectory()) {
      yield* getFiles(res);
    } else {
      yield res;
    }
  }
}

async function main() {
  for await (const f of getFiles("out/")) {
    if (!f.endsWith(".json")) {
      console.log(`Skipping non json file ${f}`);
      continue;
    }
    readFile(f, "utf-8", (err, data) => {
      if (err) {
        console.error(`Error reading file ${f}: ${err}`);
      }
      if (data) {
        const compilationArtifact = JSON.parse(data);
        const abi = compilationArtifact.abi;
        if (abi === undefined || abi === null) {
          console.error(`No abi found for ${f}, skipping`);
          return;
        } else {
          const interfaceAbi = new ethers.Interface(abi);
          interfaceAbi.forEachError((errFragment) => {
            const sighash = errFragment.selector;
            console.log(`${errFragment.name} ${sighash}`)
          });
        }
      }
    });
  }
}

main();
