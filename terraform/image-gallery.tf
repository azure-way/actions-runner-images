locals {
  prefix    = "community-gallery"
  imagePath = "../images/${var.image_type}/templates/${var.image_type}-${var.image_type_version}.pkr.hcl"
}

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "automation_resource_group" {
  name     = "rg-${local.prefix}"
}

data "azurerm_shared_image_gallery" "imageGallery" {
  name                = "azureway_community_gallery"
  resource_group_name = data.azurerm_resource_group.automation_resource_group.name
}

data "azurerm_shared_image" "image" {
  name                = "azureway-${var.short_image_name}-${var.image_type_version}"
  gallery_name        = "azureway_community_gallery"
  resource_group_name = data.azurerm_resource_group.automation_resource_group.name
}

# resource "azurerm_shared_image" "image" {
#   name                = "azureway-${var.short_image_name}-${var.image_type_version}"
#   gallery_name        = data.azurerm_shared_image_gallery.imageGallery.name
#   resource_group_name = data.azurerm_resource_group.automation_resource_group.name
#   location            = data.azurerm_resource_group.automation_resource_group.location
#   os_type             = var.os_type_map[var.image_type]

#   identifier {
#     publisher = var.self_hosted_image_publisher
#     offer     = "${var.self_hosted_image_offer}_${var.image_type}-${var.image_type_version}"
#     sku       = var.self_hosted_image_sku
#   }
# }

resource "null_resource" "packer_init" {
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset("${path.cwd}/../images/${var.image_type}", "**") : filesha1("${path.cwd}/../images/${var.image_type}/${f}")]))
    run_id   = var.run_id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/sh", "-c"]
    command     = <<EOT
      packer init ${local.imagePath}
    EOT
    }
  }

resource "null_resource" "packer_runner" {
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset("${path.cwd}/../images/${var.image_type}", "**") : filesha1("${path.cwd}/../images/${var.image_type}/${f}")]))
    run_id   = var.run_id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/sh", "-c"]
    command     = <<EOT
        packer build -var "client_id=${var.spn-client-id}" \
             -var "client_secret=${var.spn-client-secret}" \
             -var "location=${var.location}" \
             -var "install_password=7ed7e306-2c09-40b8-a40a-1d79bdbb7a47" \
             -var "subscription_id=${var.subscription-id}" \
             -var "temp_resource_group_name=temp-rg-${var.image_version}-${var.image_type}-${var.image_type_version}" \
             -var "tenant_id=${var.spn-tenant-id}" \
             -var "virtual_network_name=$null" \
             -var "virtual_network_resource_group_name=$null" \
             -var "virtual_network_subnet_name=$null" \
             -var "managed_image_name=${var.image_version}-${data.azurerm_shared_image.image.name}" \
             -var "managed_image_resource_group_name=${data.azurerm_resource_group.automation_resource_group.name}" \
             -color=false \
             "${local.imagePath}" 
    EOT

    environment = {
      POWERSHELL_TELEMETRY_OPTOUT = 1
    }
  }

  depends_on = [ null_resource.packer_init ]
}

data "azurerm_image" "image" {
  name                = "${var.image_version}-${data.azurerm_shared_image.image.name}"
  resource_group_name = data.azurerm_resource_group.automation_resource_group.name

  depends_on = [null_resource.packer_runner]
}

resource "azurerm_shared_image_version" "example" {
  name                = var.image_version
  gallery_name        = data.azurerm_shared_image.image.gallery_name
  image_name          = data.azurerm_shared_image.image.name
  resource_group_name = data.azurerm_shared_image.image.resource_group_name
  location            = data.azurerm_shared_image.image.location
  managed_image_id    = data.azurerm_image.image.id

  target_region {
    name                   = data.azurerm_shared_image.image.location
    regional_replica_count = 1
    storage_account_type   = "Standard_LRS"
  }
}
