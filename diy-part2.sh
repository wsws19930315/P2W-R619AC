#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

set -e

# 为生成的固件镜像名称添加时间戳。
sed -i 's/^IMG_PREFIX\:\=.*/IMG_PREFIX:=IM-$(shell TZ=UTC-8 date +"%Y.%m.%d-%H%M")-$(IMG_PREFIX_VERNUM)$(IMG_PREFIX_VERCODE)$(IMG_PREFIX_EXTRA)$(BOARD)$(if $(SUBTARGET),-$(SUBTARGET))/g' include/image.mk

# 下载中文默认设置，下载失败时保留上游默认值。
mkdir -p package/emortal/default-settings/files
if ! curl --retry 3 --retry-delay 5 -fsSL https://raw.githubusercontent.com/leesuncom/package/main/99-default-settings-chinese -o package/emortal/default-settings/files/99-default-settings-chinese; then
  echo "Warning: failed to download 99-default-settings-chinese, keeping upstream defaults"
fi

# 将默认 LuCI 主题从 Bootstrap 切换为 Argon。
sed -i 's/[Bb]ootstrap/argon/g' ./feeds/luci/collections/luci/Makefile

# 设置默认路由器 IP 地址。
sed -i 's/192.168.1.1/192.168.88.1/g' package/base-files/files/bin/config_generate

# 使用官方 OpenClash，避免第三方 feed 里的版本与当前 LuCI 不兼容。
find . -name Makefile -path '*openclash*' -delete
rm -rf package/openclash
git clone --depth=1 --filter=blob:none --sparse https://github.com/vernesong/OpenClash.git package/openclash
git -C package/openclash sparse-checkout set luci-app-openclash

# 使用官方 PassWall，按上游 README 的方法 2 接入。
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls}
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf package/passwall-packages
rm -rf package/passwall-luci
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall-packages package/passwall-packages
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall package/passwall-luci

# 替换 mosdns 和 v2ray-geodata 为自定义来源。
find . -name Makefile -path '*v2ray-geodata*' -delete
find . -name Makefile -path '*mosdns*' -delete
git clone https://github.com/sbwml/luci-app-mosdns -b v5 package/mosdns

# 下载自定义 mosdns 配置，失败时保留上游默认值。
mkdir -p package/mosdns/luci-app-mosdns/root/etc/config
if ! curl --retry 3 --retry-delay 5 -fsSL https://raw.githubusercontent.com/leesuncom/R619AC/master/patch/mosdns -o package/mosdns/luci-app-mosdns/root/etc/config/mosdns; then
  echo "Warning: failed to download custom mosdns config, keeping upstream defaults"
fi

# 集成 sirpdboy 插件。
rm -rf package/netwizard
rm -rf package/lucky
rm -rf package/luci-app-advanced
rm -rf package/taskplan
rm -rf package/timecontrol
git clone --depth=1 https://github.com/sirpdboy/luci-app-netwizard package/netwizard
git clone --depth=1 https://github.com/sirpdboy/luci-app-lucky package/lucky
git clone --depth=1 https://github.com/sirpdboy/luci-app-advanced package/luci-app-advanced
git clone --depth=1 https://github.com/sirpdboy/luci-app-taskplan package/taskplan
git clone --depth=1 https://github.com/sirpdboy/luci-app-timecontrol package/timecontrol

# 提前校验关键插件目录，便于上游目录结构变化时尽早失败。
for dir in \
  package/openclash/luci-app-openclash \
  package/passwall-packages \
  package/passwall-luci/luci-app-passwall \
  package/netwizard/luci-app-netwizard \
  package/lucky/luci-app-lucky \
  package/lucky/lucky \
  package/luci-app-advanced \
  package/taskplan/luci-app-taskplan \
  package/timecontrol/luci-app-timecontrol; do
  if [ ! -d "$dir" ]; then
    echo "Missing expected package directory: $dir"
    exit 1
  fi
done
