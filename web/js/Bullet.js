/**
 * Created by zhangpei on 2016/7/7.
 */

var Bullet = function(startX, startY, angle) {

    // console.log('New bullet');

    var bullet = this;

    bullet.startX = parseFloat(startX);
    bullet.startY = parseFloat(startY);
    bullet.alive = true;
    bullet.angle = parseFloat(angle);
    bullet.opacity = Math.random() * 0.5 + 0.1;

    bullet.size = 3;
    bullet.speed = 3;

    bullet.curX = bullet.startX;
    bullet.curY = bullet.startY;
    bullet.time = 0;

    bullet.update = function(model) {
        if (! bullet.alive) {
            return;
        }
        bullet.time ++;
        if (bullet.time == 100) {
            bullet.alive = false;
        }
        bullet.curX = bullet.startX + Math.cos(bullet.angle) * bullet.speed * bullet.time;
        bullet.curY = bullet.startY + Math.sin(bullet.angle) * bullet.speed * bullet.time;
    };

    bullet.draw = function(context) {
        if (! bullet.alive) {
            return;
        }
        context.fillStyle = 'rgba(255, 255, 255, 0.8)';
        context.beginPath();
        context.arc(bullet.curX, bullet.curY, bullet.size, 0, Math.PI * 2, false);
        context.closePath();
        context.fill();
    };

    bullet.collideUpdate = function(model) {
        for (var i in model.tadpoles) {
            if (model.tadpoles[i].id == model.userTadpole.id) {
                continue ;
            }
            if (isCollide(model.userTadpole)) {
                console.log('Crash');
                model.userTadpole.crash = true;
            }
        }
    };

    var isCollide = function(tadpole) {
        return Math.sqrt((tadpole.x - bullet.curX) * (tadpole.x - bullet.curX) + (tadpole.y - bullet.curY) * (tadpole.y - bullet.curY)) <= 3;
    }
};
