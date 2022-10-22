# Cordova-vk-auth

2022, @web-monster

Исправленная библиотека для авторизации VK

**Установка**

    cordova plugin add https://github.com/web-monster/cordova-vk-auth --variable VK_APP_ID=1234567 //Только цифры

**Пример использования**

    initialize: function() {
            document.addEventListener('deviceready', this.onDeviceReady.bind(this), false);
    },

    onDeviceReady: function() {
        SocialVk.init('1234567'); //APP ID только цифры
        SocialVk.login(['offline'], function (value) {
            console.log(value); //value - вернет JSON с token и user (информация аккаунта)
        });
    },

    app.initialize();