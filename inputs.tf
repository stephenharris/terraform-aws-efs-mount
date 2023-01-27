variable "name" {
  type        = string
  description = "(Required) The reference_name of your file system. Also, used in tags."
}

variable "subnets" {
  type        = list
  description = "(Required) A list of subnet ids where mount targets will be."
}

variable "vpc_id" {
  type        = string
  description = "(Required) The VPC ID where NFS security groups will be."
}

variable "encrypted" {
  description = "(Optional) If true, the disk will be encrypted"
  default     = false
  type        = bool
}

variable "kms_key_id" {
  type        = string
  description = "The ARN of the key that you wish to use if encrypting at rest. If not supplied, uses service managed encryption. Can be specified only if `encrypted = true`"
  default     = ""
}

variable "throughput_mode" {
  type        = string
  description = "thoughput mode"
  default     = "bursting"
}

variable "cidr_blocks" {
  type        = list
  description = "(Optional) A list of CIDR blocks to be allowed access to the mount points"
  default     = []
}

variable "transition_to_ia" {
  description = "Indicates how long it takes to transition files to the IA storage class"
  type        = string
  default     = ""
}

variable "tags" {
  description = "A mapping of tags to apply to resources"
  type        = map(string)
  default     = {}
}
