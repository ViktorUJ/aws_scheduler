#test
variable "work_period_second" {
  default = 3600
}
resource "time_static" "time" {
triggers = {
  time=local.time_stamp
}
}

locals {
  time_stamp=timestamp()
  target_time_stamp= sum([tonumber(time_static.time.unix),tonumber(var.work_period_second)])
}



