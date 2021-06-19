/*
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 *
 * Copyright 2021, Blender Foundation.
 */

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

struct Mesh;
struct Object;
struct Scene;
struct MeshBufferCache;

void DRW_create_subdivision(const struct Scene *scene,
                            struct Object *ob,
                            struct Mesh *mesh,
                            struct MeshBufferCache *mbc);

void DRW_subdiv_free(void);

#ifdef __cplusplus
}
#endif