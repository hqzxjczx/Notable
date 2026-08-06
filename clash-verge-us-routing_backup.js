// Define main function (script entry)

 function main(config, profileName) {
    // 1. 追加策略组
    const groups = config['proxy-groups'] || [];
    groups.push({
      name: '🚀| Google',
      type: 'url-test',
      interval: 300,
      timeout: 5000,
      'max-failed-times': 5,
      lazy: true,
      icon: '🚀',
      proxies: [
        '🇺🇸|美国-IEPL 01', '🇺🇸|美国-IEPL 02', '🇺🇸|美国-直连',
        '🇺🇸|美国-中转 01', '🇺🇸|美国-中转 02',
        '🇺🇸|美国-家宽 01 5倍消耗', '🇺🇸|美国-家宽 02 5倍消耗',
        '🇺🇸|美国-进阶中转 01', '🇺🇸|美国-进阶IEPL 02',
        'REJECT',
        // 'DIRECT'
      ]
    });
    config['proxy-groups'] = groups;

    // 2. 前置规则
    const newRules = [
      // 'DOMAIN-SUFFIX,google.com,🚀| Google',
      // 'DOMAIN-SUFFIX,googleusercontent.com,🚀| Google',
      // 'DOMAIN-SUFFIX,gstatic.com,🚀| Google',
      // 'DOMAIN-SUFFIX,googleapis.com,🚀| Google',
      // 'DOMAIN-SUFFIX,youtube.com,🚀| Google',
      // 'DOMAIN-SUFFIX,googlevideo.com,🚀| Google',
      // 'DOMAIN-SUFFIX,ytimg.com,🚀| Google',
      // 'DOMAIN-SUFFIX,ggpht.com,🚀| Google',
      // 'DOMAIN-SUFFIX,blogspot.com,🚀| Google',
      // 'DOMAIN-SUFFIX,google.com.hk,🚀| Google',
      // 'DOMAIN-SUFFIX,google.co.jp,🚀| Google',
      'GEOSITE,youtube,🚀| Google',
      'GEOSITE,google,🚀| Google'
    ];
    config.rules = newRules.concat(config.rules || []);

    return config;
  }
