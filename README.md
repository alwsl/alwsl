This project provides an easy way to install a custom, minimal, arch linux distribution as the WSL host.

If you want to try it right now, clone and run the alwsl batch file from a non-admin command prompt. 

###### Update Apr 2017

At the moment there is an upstream issues that will cause a fresh install of alwsl to break when updating for the first time.
The correct way to initiate and complete the first update is as follows:
```bash
pacman -Syuw
rm /etc/ssl/certs/ca-certificates.crt
update-ca-trust
pacman -Su
```

Once we have rebuilt an image this will no longer be an issue.

###### Update Mar 2017

We are happy to announce Fastly as a sponsor for a reliable and global delivery of alwsl root images and future updates. Fastly commited a monthly four-figure credit to the alwsl project which will help with alwsl's transition into a new version later this month.

Checkout Fastly's Open-Source efforts [here](https://www.fastly.com/open-source).

![](http://i.imgur.com/rjcltwk.png)

---

###### Update Jan 2017

We are currently negotiating with potential sponsors for a more stable delivery system for rootfs images and future updates to guarantee availability in all region at all times. In the meantime I have temporarily switched to a different internal CDN that should be faster. **If you still have an old copy of the batch script, where the CDN URL is not ___"antiquant.com"___, please download the current one!**

The next version will be released if a sponsor contract is signed. Current status: signing.

![](http://imgur.com/1T2dyE5.png)
