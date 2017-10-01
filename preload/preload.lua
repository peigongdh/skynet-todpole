-- This file will execute before every lua service start

package.path = "./shared_lib/?.lua;" .. package.path
package.path = "./shared_service/?.lua;" .. package.path
package.path = "./config/?.lua;" .. package.path

math.randomseed(os.time())